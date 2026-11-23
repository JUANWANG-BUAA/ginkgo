//! Pure ISO/IEC 18004 QR Code matrix encoder (Byte mode, ECC Level M, Versions 1..10)
//! and sanitized check-in QR ticket value. No URLs, network, or I/O dependencies.

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckInQrTicket {
    pub course_id: String,
    pub fetched_at: String,
    pub refresh_seconds: u16,
    pub matrix_size: u16,
    /// Row-major dark/light modules of length `matrix_size * matrix_size` (excluding quiet zone).
    pub modules: Vec<bool>,
}

#[derive(Clone, Copy)]
struct VersionSpec {
    version: usize,
    size: usize,
    total_codewords: usize,
    ec_per_block: usize,
    g1_blocks: usize,
    g1_data: usize,
    g2_blocks: usize,
    g2_data: usize,
    remainder_bits: usize,
    alignment: &'static [usize],
}

// ISO/IEC 18004 Table 9 for Error Correction Level M, Versions 1..10.
const SPECS: &[VersionSpec] = &[
    VersionSpec {
        version: 1,
        size: 21,
        total_codewords: 26,
        ec_per_block: 10,
        g1_blocks: 1,
        g1_data: 16,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 0,
        alignment: &[],
    },
    VersionSpec {
        version: 2,
        size: 25,
        total_codewords: 44,
        ec_per_block: 16,
        g1_blocks: 1,
        g1_data: 28,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 7,
        alignment: &[6, 18],
    },
    VersionSpec {
        version: 3,
        size: 29,
        total_codewords: 70,
        ec_per_block: 26,
        g1_blocks: 1,
        g1_data: 44,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 7,
        alignment: &[6, 22],
    },
    VersionSpec {
        version: 4,
        size: 33,
        total_codewords: 100,
        ec_per_block: 18,
        g1_blocks: 2,
        g1_data: 32,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 7,
        alignment: &[6, 26],
    },
    VersionSpec {
        version: 5,
        size: 37,
        total_codewords: 134,
        ec_per_block: 24,
        g1_blocks: 2,
        g1_data: 43,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 7,
        alignment: &[6, 30],
    },
    VersionSpec {
        version: 6,
        size: 41,
        total_codewords: 172,
        ec_per_block: 16,
        g1_blocks: 4,
        g1_data: 27,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 7,
        alignment: &[6, 34],
    },
    VersionSpec {
        version: 7,
        size: 45,
        total_codewords: 196,
        ec_per_block: 18,
        g1_blocks: 4,
        g1_data: 31,
        g2_blocks: 0,
        g2_data: 0,
        remainder_bits: 0,
        alignment: &[6, 22, 38],
    },
    VersionSpec {
        version: 8,
        size: 49,
        total_codewords: 242,
        ec_per_block: 22,
        g1_blocks: 2,
        g1_data: 38,
        g2_blocks: 2,
        g2_data: 39,
        remainder_bits: 0,
        alignment: &[6, 24, 42],
    },
    VersionSpec {
        version: 9,
        size: 53,
        total_codewords: 292,
        ec_per_block: 22,
        g1_blocks: 3,
        g1_data: 36,
        g2_blocks: 2,
        g2_data: 37,
        remainder_bits: 0,
        alignment: &[6, 26, 46],
    },
    VersionSpec {
        version: 10,
        size: 57,
        total_codewords: 346,
        ec_per_block: 26,
        g1_blocks: 4,
        g1_data: 43,
        g2_blocks: 1,
        g2_data: 44,
        remainder_bits: 0,
        alignment: &[6, 28, 50],
    },
];

/// Encode an arbitrary byte payload (up to 213 bytes) into a standard QR matrix.
#[allow(clippy::result_unit_err)]
pub fn encode_qr_matrix(text: &str) -> Result<(u16, Vec<bool>), ()> {
    let bytes = text.as_bytes();
    if bytes.is_empty() {
        return Err(());
    }
    let spec = SPECS
        .iter()
        .find(|s| {
            let data_cw = s.g1_blocks * s.g1_data + s.g2_blocks * s.g2_data;
            let len_bits = if s.version <= 9 { 8 } else { 16 };
            4 + len_bits + bytes.len() * 8 <= data_cw * 8
        })
        .ok_or(())?;

    let data_cw = spec.g1_blocks * spec.g1_data + spec.g2_blocks * spec.g2_data;
    let mut bits = Vec::with_capacity(data_cw * 8);
    push_bits(&mut bits, 0b0100, 4);
    let len_bits = if spec.version <= 9 { 8 } else { 16 };
    push_bits(&mut bits, bytes.len() as u32, len_bits);
    for &b in bytes {
        push_bits(&mut bits, b as u32, 8);
    }
    let remaining = (data_cw * 8) - bits.len();
    push_bits(&mut bits, 0, remaining.min(4));
    while !bits.len().is_multiple_of(8) {
        bits.push(0);
    }
    let mut codewords = Vec::with_capacity(data_cw);
    for chunk in bits.as_chunks::<8>().0 {
        let mut val = 0u8;
        for &bit in chunk {
            val = (val << 1) | bit;
        }
        codewords.push(val);
    }
    let pad = [0xECu8, 0x11u8];
    let mut pad_idx = 0;
    while codewords.len() < data_cw {
        codewords.push(pad[pad_idx % 2]);
        pad_idx += 1;
    }

    let final_bits = build_interleaved_bits(spec, &codewords);
    let matrix = render_best_matrix(spec, &final_bits);
    Ok((spec.size as u16, matrix))
}

fn push_bits(out: &mut Vec<u8>, value: u32, count: usize) {
    for shift in (0..count).rev() {
        out.push(((value >> shift) & 1) as u8);
    }
}

fn gf_mul(mut a: u8, mut b: u8) -> u8 {
    let mut res = 0u8;
    while b > 0 {
        if (b & 1) != 0 {
            res ^= a;
        }
        let hi = a & 0x80;
        a <<= 1;
        if hi != 0 {
            a ^= 0x1D;
        }
        b >>= 1;
    }
    res
}

fn rs_generator(degree: usize) -> Vec<u8> {
    let mut poly = vec![1u8];
    let mut root = 1u8;
    for _ in 0..degree {
        let mut next = vec![0u8; poly.len() + 1];
        for (i, &coeff) in poly.iter().enumerate() {
            next[i] ^= coeff;
            next[i + 1] ^= gf_mul(coeff, root);
        }
        poly = next;
        root = gf_mul(root, 2);
    }
    poly
}

fn rs_remainder(data: &[u8], degree: usize) -> Vec<u8> {
    let gen = rs_generator(degree);
    let mut rem = vec![0u8; degree];
    for &byte in data {
        let factor = byte ^ rem[0];
        rem.rotate_left(1);
        rem[degree - 1] = 0;
        for i in 0..degree {
            rem[i] ^= gf_mul(gen[i + 1], factor);
        }
    }
    rem
}

fn build_interleaved_bits(spec: &VersionSpec, data: &[u8]) -> Vec<u8> {
    let mut data_blocks = Vec::new();
    let mut ec_blocks = Vec::new();
    let mut offset = 0;
    for _ in 0..spec.g1_blocks {
        let block = &data[offset..offset + spec.g1_data];
        ec_blocks.push(rs_remainder(block, spec.ec_per_block));
        data_blocks.push(block);
        offset += spec.g1_data;
    }
    for _ in 0..spec.g2_blocks {
        let block = &data[offset..offset + spec.g2_data];
        ec_blocks.push(rs_remainder(block, spec.ec_per_block));
        data_blocks.push(block);
        offset += spec.g2_data;
    }

    let max_data = spec.g1_data.max(spec.g2_data);
    let mut interleaved = Vec::with_capacity(spec.total_codewords);
    for i in 0..max_data {
        for block in &data_blocks {
            if let Some(&b) = block.get(i) {
                interleaved.push(b);
            }
        }
    }
    for i in 0..spec.ec_per_block {
        for block in &ec_blocks {
            interleaved.push(block[i]);
        }
    }
    let mut bits = Vec::with_capacity(interleaved.len() * 8 + spec.remainder_bits);
    for b in interleaved {
        push_bits(&mut bits, b as u32, 8);
    }
    bits.resize(bits.len() + spec.remainder_bits, 0);
    bits
}

fn set_func_cell(
    is_func: &mut [bool],
    base: &mut [bool],
    n: usize,
    r: usize,
    c: usize,
    dark: bool,
) {
    is_func[r * n + c] = true;
    base[r * n + c] = dark;
}

fn render_best_matrix(spec: &VersionSpec, bits: &[u8]) -> Vec<bool> {
    let n = spec.size;
    let mut is_func = vec![false; n * n];
    let mut base = vec![false; n * n];

    for &(fr, fc) in &[(0usize, 0usize), (0, n - 7), (n - 7, 0)] {
        for dr in -1i32..=7 {
            for dc in -1i32..=7 {
                let rr = fr as i32 + dr;
                let cc = fc as i32 + dc;
                if rr >= 0 && cc >= 0 && (rr as usize) < n && (cc as usize) < n {
                    let dist = dr.abs_diff(3).max(dc.abs_diff(3));
                    let dark = dist != 2 && dist != 4;
                    set_func_cell(&mut is_func, &mut base, n, rr as usize, cc as usize, dark);
                }
            }
        }
    }

    for &ar in spec.alignment {
        for &ac in spec.alignment {
            let overlaps_finder =
                (ar <= 8 && ac <= 8) || (ar <= 8 && ac >= n - 9) || (ar >= n - 9 && ac <= 8);
            if overlaps_finder {
                continue;
            }
            for dr in -2i32..=2 {
                for dc in -2i32..=2 {
                    let dark = dr.abs().max(dc.abs()) != 1;
                    set_func_cell(
                        &mut is_func,
                        &mut base,
                        n,
                        (ar as i32 + dr) as usize,
                        (ac as i32 + dc) as usize,
                        dark,
                    );
                }
            }
        }
    }

    for i in 8..(n - 8) {
        let dark = i % 2 == 0;
        if !is_func[6 * n + i] {
            set_func_cell(&mut is_func, &mut base, n, 6, i, dark);
        }
        if !is_func[i * n + 6] {
            set_func_cell(&mut is_func, &mut base, n, i, 6, dark);
        }
    }

    set_func_cell(&mut is_func, &mut base, n, n - 8, 8, true);

    for i in 0..9 {
        if i != 6 {
            is_func[8 * n + i] = true;
            is_func[i * n + 8] = true;
        }
    }
    for i in 0..8 {
        is_func[8 * n + (n - 1 - i)] = true;
    }
    for i in 0..7 {
        is_func[(n - 1 - i) * n + 8] = true;
    }

    if spec.version >= 7 {
        let ver_bits = version_info_bits(spec.version as u32);
        for i in 0..18 {
            let dark = ((ver_bits >> i) & 1) != 0;
            let a = n - 11 + (i % 3);
            let b = i / 3;
            set_func_cell(&mut is_func, &mut base, n, b, a, dark);
            set_func_cell(&mut is_func, &mut base, n, a, b, dark);
        }
    }

    let mut data_grid = base;
    let mut bit_idx = 0usize;
    let mut right = (n as i32) - 1;
    while right >= 1 {
        if right == 6 {
            right -= 1;
        }
        let upward = ((n as i32 - 1 - right) / 2) % 2 == 0;
        for step in 0..n {
            let row = if upward { n - 1 - step } else { step };
            for col_offset in 0..2 {
                let col = (right - col_offset) as usize;
                if !is_func[row * n + col] {
                    let bit = bits.get(bit_idx).copied().unwrap_or(0) != 0;
                    data_grid[row * n + col] = bit;
                    bit_idx += 1;
                }
            }
        }
        right -= 2;
    }

    let mut best_penalty = u32::MAX;
    let mut best_grid = data_grid.clone();
    for mask in 0..8u32 {
        let mut grid = data_grid.clone();
        for r in 0..n {
            for c in 0..n {
                if !is_func[r * n + c] && mask_bit(mask, r, c) {
                    grid[r * n + c] = !grid[r * n + c];
                }
            }
        }
        write_format_info(&mut grid, n, mask);
        let penalty = penalty_score(&grid, n);
        if penalty < best_penalty {
            best_penalty = penalty;
            best_grid = grid;
        }
    }
    best_grid
}

fn mask_bit(mask: u32, r: usize, c: usize) -> bool {
    match mask {
        0 => (r + c).is_multiple_of(2),
        1 => r.is_multiple_of(2),
        2 => c.is_multiple_of(3),
        3 => (r + c).is_multiple_of(3),
        4 => ((r / 2) + (c / 3)).is_multiple_of(2),
        5 => (r * c).is_multiple_of(2) && (r * c).is_multiple_of(3),
        6 => (((r * c) % 2) + ((r * c) % 3)).is_multiple_of(2),
        7 => (((r + c) % 2) + ((r * c) % 3)).is_multiple_of(2),
        _ => false,
    }
}

fn format_info_bits(mask: u32) -> u32 {
    let data = mask & 0b111;
    let mut rem = data << 10;
    for shift in (10..=14).rev() {
        if ((rem >> shift) & 1) != 0 {
            rem ^= 0b101_0011_0111 << (shift - 10);
        }
    }
    ((data << 10) | rem) ^ 0b101_0100_0001_0010
}

fn version_info_bits(version: u32) -> u32 {
    let mut rem = version << 12;
    for shift in (12..=17).rev() {
        if ((rem >> shift) & 1) != 0 {
            rem ^= 0b1_1111_0010_0101 << (shift - 12);
        }
    }
    (version << 12) | rem
}

fn write_format_info(grid: &mut [bool], n: usize, mask: u32) {
    let fmt = format_info_bits(mask);
    for i in 0..15 {
        let dark = ((fmt >> (14 - i)) & 1) != 0;
        if i < 6 {
            grid[8 * n + i] = dark;
        } else if i == 6 {
            grid[8 * n + 7] = dark;
        } else if i == 7 {
            grid[8 * n + 8] = dark;
        } else if i == 8 {
            grid[7 * n + 8] = dark;
        } else {
            grid[(14 - i) * n + 8] = dark;
        }
        if i < 7 {
            grid[(n - 1 - i) * n + 8] = dark;
        } else {
            grid[8 * n + (n - 15 + i)] = dark;
        }
    }
}

fn penalty_score(grid: &[bool], n: usize) -> u32 {
    let mut score = 0u32;
    for r in 0..n {
        let mut run_color = grid[r * n];
        let mut run_len = 1u32;
        for c in 1..n {
            if grid[r * n + c] == run_color {
                run_len += 1;
            } else {
                if run_len >= 5 {
                    score += 3 + (run_len - 5);
                }
                run_color = grid[r * n + c];
                run_len = 1;
            }
        }
        if run_len >= 5 {
            score += 3 + (run_len - 5);
        }
    }
    for c in 0..n {
        let mut run_color = grid[c];
        let mut run_len = 1u32;
        for r in 1..n {
            if grid[r * n + c] == run_color {
                run_len += 1;
            } else {
                if run_len >= 5 {
                    score += 3 + (run_len - 5);
                }
                run_color = grid[r * n + c];
                run_len = 1;
            }
        }
        if run_len >= 5 {
            score += 3 + (run_len - 5);
        }
    }
    for r in 0..(n - 1) {
        for c in 0..(n - 1) {
            let v = grid[r * n + c];
            if v == grid[r * n + c + 1]
                && v == grid[(r + 1) * n + c]
                && v == grid[(r + 1) * n + c + 1]
            {
                score += 3;
            }
        }
    }
    for r in 0..n {
        for c in 0..=(n - 11) {
            if matches_finder_pattern((0..11).map(|k| grid[r * n + c + k])) {
                score += 40;
            }
        }
    }
    for c in 0..n {
        for r in 0..=(n - 11) {
            if matches_finder_pattern((0..11).map(|k| grid[(r + k) * n + c])) {
                score += 40;
            }
        }
    }
    let dark_count = grid.iter().filter(|&&b| b).count() as i32;
    let total = (n * n) as i32;
    let percent = (dark_count * 100) / total;
    let prev5 = (percent / 5) * 5;
    let next5 = prev5 + 5;
    let diff = ((prev5 - 50).abs() / 5).min((next5 - 50).abs() / 5) as u32;
    score += diff * 10;
    score
}

fn matches_finder_pattern(iter: impl Iterator<Item = bool>) -> bool {
    let mut bits = [false; 11];
    for (idx, b) in iter.enumerate() {
        bits[idx] = b;
    }
    const P1: [bool; 11] = [
        true, false, true, true, true, false, true, false, false, false, false,
    ];
    const P2: [bool; 11] = [
        false, false, false, false, true, false, true, true, true, false, true,
    ];
    bits == P1 || bits == P2
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_valid_square_matrices_and_rejects_empty_or_oversized_inputs() {
        assert!(encode_qr_matrix("").is_err());
        assert!(encode_qr_matrix(&"x".repeat(214)).is_err());

        let (size_v1, grid_v1) = encode_qr_matrix("HELLO").expect("v1");
        assert_eq!(size_v1, 21);
        assert_eq!(grid_v1.len(), 21 * 21);
        // Top-left finder corner and center must be dark.
        assert!(grid_v1[0]);
        assert!(grid_v1[3 * 21 + 3]);

        let sample =
            "http://example.invalid:8081/app/course/stu_scan_sign.action?courseSchedId=1000001&timestamp=1700000000000";
        let (size_v6, grid_v6) = encode_qr_matrix(sample).expect("v6");
        assert_eq!(size_v6, 41);
        assert_eq!(grid_v6.len(), 41 * 41);
    }
}
