'use strict';
// All relationships below come from graph-data.js. Layout never invents an edge.
const graph = window.GINKGO_GRAPH;
const nodes = new Map(graph.nodes.map(node => [node.id, node]));
const outgoing = new Map(), incoming = new Map();
for (const edge of graph.edges) {
  if (!outgoing.has(edge.from)) outgoing.set(edge.from, []);
  outgoing.get(edge.from).push(edge);
  if (edge.to !== null) {
    if (!incoming.has(edge.to)) incoming.set(edge.to, []);
    incoming.get(edge.to).push(edge);
  }
}
const names = {call:'调用',construct:'构造',invoke:'函数值调用',reference:'引用 / 回调',contains:'词法包含',implementation:'实现候选',await:'等待点','ffi-pair':'FRB 配对','syntax-call':'语法调用 · 目标未解析'};
const direct = new Set(['call','construct','invoke']);
const $ = selector => document.querySelector(selector);
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const link = node => node ? `<button data-node="${node.id}">${escape(node.name)}</button>` : '<span class="muted">目标未解析</span>';
const sourceLink = (file,line) => `<button data-file="${escape(file)}" data-line="${line || 1}">${escape(file)}:${line || '?'}</button>`;
let selected = graph.nodes.find(n => n.file === 'flutter/lib/main.dart' && n.name === 'main')?.id ?? 0;
let mode = 'calls', limit = 60, indirect = true, external = false;
for (const group of [...new Set(graph.nodes.filter(n=>!n.external).map(n=>n.group))].sort()) {
  const option = document.createElement('option'); option.textContent = group; $('#group').append(option);
}
function search() {
  const query = $('#search').value.trim().toLowerCase();
  const results = graph.nodes.filter(n=>!n.external && (!$('#language').value || n.language===$('#language').value) && (!$('#group').value || n.group===$('#group').value) && `${n.name} ${n.file}`.toLowerCase().includes(query));
  $('#resultCount').textContent = `${results.length} 个项目符号 · 显示 ${Math.min(limit,results.length)}`;
  $('#results').innerHTML = results.slice(0,limit).map(n=>`<button data-node="${n.id}">${escape(n.name)}<small>${escape(n.file)}:${n.line || '?'}</small></button>`).join('');
  $('#more').hidden = results.length <= limit;
}
function edgeTable(edges, side='out') {
  return `<div class="table-wrap"><table><thead><tr><th>关系</th><th>${side==='in'?'调用 / 引用方':'目标'}</th><th>证据位置</th></tr></thead><tbody>${edges.map(e=>`<tr><td>${escape(names[e.kind] || e.kind)}</td><td>${link(nodes.get(side==='in'?e.from:e.to))}${e.to===null?`<div class="muted">${escape(e.label)}</div>`:''}</td><td>${sourceLink(e.file,e.line)}</td></tr>`).join('') || '<tr><td colspan="3">当前筛选没有关系；不等于运行时没有行为。</td></tr>'}</tbody></table></div>`;
}
function neighborSvg(node, ins, outs) {
  const unique = (edges,key) => [...new Map(edges.filter(e=>e[key]!==null && nodes.has(e[key])).map(e=>[e[key],{node:nodes.get(e[key]),kind:e.kind}])).values()];
  const left=unique(ins,'from').slice(0,12), right=unique(outs,'to').slice(0,12);
  const height=Math.max(180,Math.max(left.length,right.length)*64+40), middle=height/2;
  const shorten = (text,n) => text.length>n ? text.slice(0,n-1)+'…' : text;
  const box=(n,x,y,active=false)=>`<g role="button" tabindex="0" data-node="${n.id}" class="${active?'selected':''}" aria-label="${escape(n.name)}"><title>${escape(n.name+' · '+n.file)}</title><rect x="${x}" y="${y-24}" width="238" height="48" rx="6"/><text x="${x+10}" y="${y-4}">${escape(shorten(n.name,29))}</text><text class="sub" x="${x+10}" y="${y+13}">${escape(shorten(n.group,32))}</text></g>`;
  const wire=(x1,y1,x2,y2,kind)=>`<path class="${direct.has(kind)?'':'indirect'}" marker-end="url(#arrow)" d="M${x1},${y1} C${(x1+x2)/2},${y1} ${(x1+x2)/2},${y2} ${x2},${y2}"/>`;
  return `<div class="graph"><svg viewBox="0 0 1000 ${height}" aria-label="自动布局的一跳调用关系"><defs><marker id="arrow" markerWidth="7" markerHeight="7" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6" style="fill:var(--accent);stroke:none"/></marker></defs>${left.map((item,i)=>wire(250,i*64+40,380,middle,item.kind)).join('')}${right.map((item,i)=>wire(618,middle,748,i*64+40,item.kind)).join('')}${left.map((item,i)=>box(item.node,12,i*64+40)).join('')}${box(node,380,middle,true)}${right.map((item,i)=>box(item.node,748,i*64+40)).join('')}</svg></div><p class="muted">左侧指向当前符号，当前符号指向右侧。实线：调用 / 构造；虚线：引用、包含、候选或配对。每侧最多 12 个不同符号，完整关系见下表。点击节点继续追踪。</p>`;
}
function showSource(file,line=1,end=line+12) {
  const source=graph.sources[file];
  $('#source').innerHTML = `<h3>源码 · ${escape(file)}:${line}</h3>`+(source?`<p class="muted">来自同一分析快照。高亮选定范围；上下各保留 5 行。可展开完整文件。</p><pre>${source.slice(Math.max(0,line-6),Math.min(source.length,end+5)).map((text,i)=>{const number=Math.max(0,line-6)+i+1;return `<span class="code-line ${number>=line && number<=end?'focus':''}"><b>${number}</b>${escape(text)}</span>`;}).join('')}</pre><details><summary>完整文件 · ${source.length} 行</summary><pre>${source.map((text,i)=>`<span class="code-line"><b>${i+1}</b>${escape(text)}</span>`).join('')}</pre></details>`:'<p>外部依赖或生成绑定未嵌入正文；请按路径查看对应工具链 / 仓库文件。</p>');
}
function calls() {
  const node=nodes.get(selected);
  const visible=e=>(indirect || direct.has(e.kind)) && (external || !nodes.get(e.to)?.external);
  const ins=(incoming.get(selected)||[]).filter(visible), outs=(outgoing.get(selected)||[]).filter(visible);
  $('#content').innerHTML=`<span class="badge">${escape(node.language)}</span><span class="badge">${escape(node.group)}</span><h2>${escape(node.name)}</h2><p class="muted">${escape(node.file)}:${node.line || '?'}${node.external?' · 外部依赖':''}</p><div class="toolbar"><label><input id="indirect" type="checkbox" ${indirect?'checked':''}>引用、包含与实现候选</label><label><input id="external" type="checkbox" ${external?'checked':''}>外部依赖</label><button id="back">返回上个节点</button></div>${neighborSvg(node,ins,outs)}<h3>调用 / 引用方 · ${ins.length} 个位置</h3>${edgeTable(ins,'in')}<h3>向外关系 · ${outs.length} 个位置</h3>${edgeTable(outs)}<section id="source"></section>`;
  $('#indirect').onchange=e=>{indirect=e.target.checked;calls();}; $('#external').onchange=e=>{external=e.target.checked;calls();}; $('#back').onclick=()=>history.back();
  showSource(node.file,node.line || 1,node.endLine || (node.line || 1)+12);
  if(!node.line) $('#source').insertAdjacentHTML('afterbegin','<p>解析器未给出该符号的独立声明行号；以下仅为所在文件参考，不能将第 1 行视为定义。</p>');
  $('#source').insertAdjacentHTML('beforebegin','<details><summary>查找静态可达路径</summary><p class="muted">以当前符号为起点，使用当前关系筛选寻找最短路径。包含候选与回调的路径不代表执行顺序；没有路径也可能是框架调度或跨语言边界未解析。</p><label for="pathSearch">目标符号</label><input id="pathSearch" type="search" placeholder="输入函数名或路径"><select id="pathTarget" aria-label="路径目标"></select><button id="findPath">查找路径</button><div id="pathResult"></div></details>');
  $('#pathSearch').oninput=()=>{const q=$('#pathSearch').value.toLowerCase();$('#pathTarget').innerHTML=graph.nodes.filter(n=>!n.external && `${n.name} ${n.file}`.toLowerCase().includes(q)).slice(0,40).map(n=>`<option value="${n.id}">${escape(n.name+' · '+n.file)}</option>`).join('');};
  $('#findPath').onclick=()=>{
    if(!$('#pathTarget').value){$('#pathResult').textContent='先输入并选择目标符号。';return;}
    const target=Number($('#pathTarget').value), previous=new Map([[selected,null]]), queue=[selected];
    for(let i=0;i<queue.length && !previous.has(target);i++) for(const e of outgoing.get(queue[i])||[]) {if(e.to===null || !visible(e) || previous.has(e.to))continue;previous.set(e.to,e);queue.push(e.to);}
    if(!previous.has(target)){$('#pathResult').textContent='当前解析数据与关系筛选中没有可达路径。';return;}
    const path=[];for(let at=target;at!==selected;){const e=previous.get(at);path.unshift(e);at=e.from;}
    $('#pathResult').innerHTML=path.length?'<p>找到 '+path.length+' 步静态关系；请逐条检查关系类型。</p>'+edgeTable(path):'<p>起点与目标相同。</p>';
  };
}
function modules() {
  const counts=new Map();
  for(const e of graph.edges) { const a=nodes.get(e.from),b=nodes.get(e.to);if(!direct.has(e.kind)||!b||a.external||b.external||a.group===b.group)continue;const key=a.group+' → '+b.group;counts.set(key,(counts.get(key)||0)+1); }
  const rows=[...counts].sort((a,b)=>b[1]-a[1]);
  const crates=[...new Set(graph.crateEdges.flatMap(e=>[e.from,e.to]))].sort();
  const levels=new Map();
  function rank(name,visiting=new Set()) {
    if(levels.has(name))return levels.get(name);
    if(visiting.has(name))return 0;
    const next=new Set(visiting);next.add(name);
    const dependencies=graph.crateEdges.filter(e=>e.from===name).map(e=>e.to);
    const value=dependencies.length?1+Math.max(...dependencies.map(n=>rank(n,next))):0;
    levels.set(name,value);return value;
  }
  crates.forEach(name=>rank(name));
  const maxRank=Math.max(...levels.values()), positions=new Map();
  const height=300;
  for(let level=0;level<=maxRank;level++) {
    const members=crates.filter(name=>levels.get(name)===level);
    members.forEach((name,i)=>positions.set(name,{x:20+(maxRank-level)*245,y:height*(i+1)/(members.length+1)}));
  }
  const svg=`<div class="graph"><svg viewBox="0 0 1000 ${height}" aria-label="Cargo metadata 依赖关系"><defs><marker id="crate-arrow" markerWidth="7" markerHeight="7" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6" style="fill:var(--accent);stroke:none"/></marker></defs>${graph.crateEdges.map(e=>{const a=positions.get(e.from),b=positions.get(e.to),x=a.x+210;const curve=b.x-x>200?`M${x},${a.y} C${x+40},${a.y-120} ${b.x-40},${b.y-120} ${b.x},${b.y}`:`M${x},${a.y} C${(x+b.x)/2},${a.y} ${(x+b.x)/2},${b.y} ${b.x},${b.y}`;return `<path marker-end="url(#crate-arrow)" d="${curve}"><title>${escape(e.from+' → '+e.to)}</title></path>`;}).join('')}${crates.map(c=>{const p=positions.get(c);return `<rect x="${p.x}" y="${p.y-23}" width="210" height="46" rx="6"/><text x="${p.x+8}" y="${p.y+4}" style="font-size:11px">${escape(c)}</text>`;}).join('')}</svg></div><p class="muted">布局层级由依赖自动计算，箭头从依赖方指向被依赖方。</p>`;
  $('#content').innerHTML=`<h2>依赖与调用，分别看。</h2><p>Rust crate 图来自 Cargo metadata；Dart 导入来自源码导入指令；模块调用量来自类型解析后的调用位置。</p><h3>Rust crate 依赖</h3>${svg}<div class="table-wrap"><table><tr><th>依赖方</th><th>被依赖方</th><th>类型 / 条件</th></tr>${graph.crateEdges.map(e=>`<tr><td>${escape(e.from)}</td><td>${escape(e.to)}</td><td>${escape(e.kind)} ${escape(e.target||'')}</td></tr>`).join('')}</table></div><h3>跨模块调用位置 · ${rows.length} 组</h3><p class="muted">仅统计 call / construct / invoke。不是运行频率，不含实现候选和回调引用。目录聚合环不能代替文件依赖环。</p><div class="table-wrap"><table><tr><th>方向</th><th>调用位置数</th></tr>${rows.map(([name,count])=>`<tr><td>${escape(name)}</td><td>${count}</td></tr>`).join('')}</table></div><details><summary>Dart 文件导入 / 导出 · ${graph.imports.length} 条</summary><div class="table-wrap"><table><tr><th>源文件</th><th>目标文件</th><th>关系</th></tr>${graph.imports.map(([a,b,c])=>`<tr><td>${escape(a)}</td><td>${escape(b)}</td><td>${escape(c)}</td></tr>`).join('')}</table></div></details><p>文件强连通分量：${escape(JSON.stringify(graph.meta.fileCycles))}；目录强连通分量：${escape(JSON.stringify(graph.meta.directoryCycles))}。</p>`;
}
function concurrency() {
  // These labels classify already-extracted targets/AST events, never create calls.
  const pattern=/^(?:.*\.)?(?:spawn|spawn_blocking|lock|read|write|try_lock|timeout|wait|abort|cancel|execute|schedule|Timer|periodic|unawaited|runZonedGuarded)$/;
  const edges=graph.edges.filter(e=>e.kind==='await'||(direct.has(e.kind)&&pattern.test(nodes.get(e.to)?.name||''))||(e.kind==='syntax-call'&&/\b(execute|launch|synchronized|post|cancel|schedule)\b/.test(e.label)));
  $('#content').innerHTML=`<h2>并发机制的源码入口</h2><p>从已解析调用目标与 await 语法事件中筛选。名称仅用于分类；read / write 等同名业务方法也可能入选，须结合类型和源码判断。Kotlin 调用点仅有语法证据。</p><p class="muted">这张清单不证明锁持有区间、线程归属、超时传播或任务取消。点击调用方和证据，逐级审阅真实实现。${edges.length} 个候选位置。</p><div class="table-wrap"><table><thead><tr><th>调用方</th><th>机制 / 目标</th><th>证据</th></tr></thead><tbody>${edges.map(e=>`<tr><td>${link(nodes.get(e.from))}</td><td>${e.to===null?escape(e.kind==='await'?'await':e.label):link(nodes.get(e.to))}</td><td>${sourceLink(e.file,e.line)}</td></tr>`).join('')}</tbody></table></div><section id="source"></section>`;
}
function coverage() {
  const m=graph.meta;
  const unresolved=graph.edges.filter(e=>e.to===null && e.kind!=='await');
  const unlocated=graph.nodes.filter(n=>!n.external && !n.line);
  $('#content').innerHTML=`<h2>图能证明什么，哪里仍有缺口。</h2><p>这是一份源码快照的静态关系索引，不是运行时调用轨迹。原始工具结果保留在本机 artifacts/local；仓库保存合并数据和源码哈希。</p><div class="cards"><div class="card"><strong>${graph.nodes.length}</strong>符号（含外部边界）</div><div class="card"><strong>${graph.edges.length}</strong>关系 / 语法事件</div><div class="card"><strong>${m.ffiPairs}</strong>FRB 生成规则配对</div></div><p>快照指纹 <code>${escape(m.sourceFingerprint)}</code></p><p class="muted">分析基点提交 ${escape(m.revision)}；快照可含当时工作树改动，以 source-manifest.json 的哈希为准。</p><div class="table-wrap"><table><tr><th>工具</th><th>版本 / 范围</th></tr>${Object.entries(m.tools).map(([k,v])=>`<tr><td>${escape(k)}</td><td>${escape(v)} · ${m.files[k]} 个文件</td></tr>`).join('')}</table></div><h3>必须保留的解释边界</h3><ul><li>Dart 解析生成 API 包装入口，但不展开 FRB 序列化内部。引用和闭包归属不等于调用。</li><li>Rust 使用 Android target，不展开过程宏，不分析测试模块；inactive cfg 和无法准备调用层级的符号列在下方。</li><li>implementation 来自类型层级 / LSP 查询，只表示候选实现，未证明运行时接收者。</li><li>Kotlin 使用语法树，未解析重载或接收者。JNI、MethodChannel 不自动跨语言连线。</li><li>FRB 配对遵循文件路径和生成命名规则，属于映射证据，不是跨语言编译证明。</li><li>没有展开的动态调用、宏、反射与平台分支不能按零行为处理。当前无文件导入环也不证明业务解耦完成。</li></ul><h3>未解析调用目标 · ${unresolved.length} 个位置</h3><p class="muted">这些是已发现的调用语法，尚不能静态确定目标；await 是等待事件，另行计数。</p>${edgeTable(unresolved)}<details><summary>无独立声明行号的项目符号 · ${unlocated.length}</summary>${unlocated.map(n=>`<p>${link(n)} ${escape(n.file)}</p>`).join('')}</details><h3>关系分类</h3><div class="table-wrap"><table>${Object.entries(m.counts).map(([k,v])=>`<tr><td>${escape(names[k]||k)}</td><td>${v}</td></tr>`).join('')}</table></div><details open><summary>工具配置与所有未解析项</summary><pre>${escape(JSON.stringify({configuration:m.rustConfiguration,status:m.rustStatus,issues:m.issues},null,2))}</pre></details>`;
}
function render(){for(const button of document.querySelectorAll('nav button'))button.setAttribute('aria-pressed',String(button.dataset.mode===mode));({calls,modules,concurrency,coverage}[mode])();}
function select(id,push=true){if(!nodes.has(id))return;selected=id;mode='calls';if(push)history.pushState(null,'',`#node=${id}`);render();}
document.addEventListener('click',event=>{const node=event.target.closest('[data-node]');if(node){select(Number(node.dataset.node));return;}const file=event.target.closest('[data-file]');if(file){if(!$('#source'))$('#content').insertAdjacentHTML('beforeend','<section id="source"></section>');showSource(file.dataset.file,Number(file.dataset.line));$('#source').scrollIntoView({block:'start'});}});
document.addEventListener('keydown',event=>{if((event.key==='Enter'||event.key===' ')&&event.target.matches('g[data-node]')){event.preventDefault();select(Number(event.target.dataset.node));}});
for(const button of document.querySelectorAll('nav button'))button.onclick=()=>{mode=button.dataset.mode;render();};
for(const input of [$('#search'),$('#language'),$('#group')])input.addEventListener('input',()=>{limit=60;search();});
$('#more').onclick=()=>{limit+=60;search();};
window.addEventListener('popstate',()=>select(Number(locationHash()),false));
function locationHash(){return new URLSearchParams(window.location.hash.slice(1)).get('node') ?? selected;}
search();select(Number(locationHash()),false);
