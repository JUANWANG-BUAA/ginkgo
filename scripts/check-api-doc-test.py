#!/usr/bin/env python3
"""check-api-doc.py 的回归测试：锁定锚点规则、代码剥离与链接判定。"""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'check_api_doc', Path(__file__).with_name('check-api-doc.py')
)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class AnchorTests(unittest.TestCase):
    def test_cjk_punctuation_is_dropped_like_github_does(self):
        # `### 2.4 周课表（核心）` 的真实锚点：点号与全角括号都被剔除，
        # CJK 表意文字属于字母因此保留，空格转连字符。
        found = module.anchors('### 2.4 周课表（核心）\n')
        self.assertEqual(found, {'24-周课表核心'})

    def test_inline_code_and_underscores_do_not_survive(self):
        found = module.anchors('### 6B.1 `官方前端` 静态修订_未执行写\n')
        self.assertEqual(found, {'6b1-官方前端-静态修订未执行写'})

    def test_only_headings_produce_anchors(self):
        self.assertEqual(module.anchors('正文里 # 不是标题\n'), set())


class StripCodeTests(unittest.TestCase):
    def test_regex_character_classes_are_not_links(self):
        text = 'A real [link](API.md#1-流程) and `[^"\']+` inside code.\n'
        stripped = module.strip_code(text)
        self.assertEqual(module.LINK.findall(stripped), ['API.md#1-流程'])

    def test_fenced_blocks_are_skipped_entirely(self):
        text = '```\n[fake](missing.md)\n```\n[real](present.md)\n'
        self.assertEqual(module.strip_code(text).count('fake'), 0)
        self.assertEqual(module.LINK.findall(module.strip_code(text)), ['present.md'])


class LinkTests(unittest.TestCase):
    def test_missing_file_and_missing_anchor_are_both_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            docs = root / 'docs'
            docs.mkdir()
            (docs / 'API.md').write_text('## 1. 流程总览\n', encoding='utf-8')
            (docs / 'INDEX.md').write_text(
                '[good](API.md#1-流程总览)\n'
                '[bad anchor](API.md#9-不存在)\n'
                '[bad file](missing.md)\n',
                encoding='utf-8',
            )
            previous_root, previous_docs = module.ROOT, module.DOCS
            module.ROOT, module.DOCS = root, docs
            try:
                broken, total = module.check_links()
            finally:
                module.ROOT, module.DOCS = previous_root, previous_docs
            self.assertEqual(total, 3)
            self.assertEqual(len(broken), 2)
            self.assertTrue(any('锚点不存在' in item for item in broken))
            self.assertTrue(any('文件不存在' in item for item in broken))


class CommandShapeTests(unittest.TestCase):
    def test_envelope_commands_are_counted_from_generated_bindings(self):
        with tempfile.TemporaryDirectory() as directory:
            api = Path(directory)
            (api / 'live.dart').write_text(
                'Future<ReadOnlyResponse> loadNotices() async => throw 0;\n'
                'Future<CareerEventsResponse> loadCareerEvents() async => throw 0;\n'
                'Future<void> initApp() async => throw 0;\n',
                encoding='utf-8',
            )
            previous = module.API_DIR
            module.API_DIR = api
            try:
                total, envelope = module.command_shapes()
            finally:
                module.API_DIR = previous
            self.assertEqual(total, 3)
            self.assertEqual(envelope, ['loadNotices'])


if __name__ == '__main__':
    unittest.main()
