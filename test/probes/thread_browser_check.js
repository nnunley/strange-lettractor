// Execute the shipped browser script against a small DOM/transport fixture.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync('src/attractor/thread_ui.lg', 'utf8');
const page = [...source.matchAll(/^\s*(".*")\s*$/gm)].map(m=>JSON.parse(m[1])).join('');
class Element {
  constructor(tag){this.tag=tag;this.children=[];this.dataset={};this.style={};this.value='';this.scrollHeight=100;this.scrollTop=0;this.clientHeight=100;}
  append(...children){this.children.push(...children)}
  replaceChildren(...children){this.children=children}
  setAttribute(k,v){this[k]=v}
  requestSubmit(){this.onsubmit({preventDefault(){}})}
  querySelectorAll(selector){const all=this.children.flatMap(c=>[c,...c.querySelectorAll(selector)]);return all.filter(c=>c.tag==='details'&&(!selector.includes('[open]')||c.open));}
}
const elements = Object.fromEntries(['tree','title','metadata','persistence','status','transcript','draft','behavior','send','cancel','resume','new','compose'].map(id=>[id,new Element(id)]));
const calls=[];let archived=false,persistenceError=null;
const threads=[{thread_id:'root',state:'idle',task:'Root'},{thread_id:'child',parent_id:'root',state:'idle',task:'<script>bad()</script>'}];
const sandbox={document:{getElementById:id=>elements[id],createElement:tag=>new Element(tag)},setInterval:()=>{},fetch:async(path,options)=>{
  calls.push({path,options});let value;
  if(path==='/threads')value=options.method?{session_id:'new'}:threads;
  else if(path.endsWith('/resume'))value={thread_id:'resumed'};
  else value={thread_id:path.split('/')[2],archived,task:'Small task title',model:'fixture/model',state:'idle',persistence_error:persistenceError,history:[{role:'user',content:'<img src=x onerror=bad()>'},{role:'assistant',tool_calls:[{id:'call-7',name:'read_file',arguments:{path:'a'}}]},{role:'tool',results:[{tool_call_id:'call-7',content:'ok'}]}],pending:[]};
  return {ok:true,json:async()=>value};
}};
vm.createContext(sandbox);vm.runInContext(page.match(/<script>([\s\S]*)<\/script>/)[1],sandbox);
const settle=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{
 await settle();
 elements.draft.value='First message without setup';elements.behavior.value='steer';
 elements.compose.onsubmit({preventDefault(){}});await settle();
 assert(calls.some(c=>c.path==='/threads'&&c.options.method==='POST'),'First message must create a conversation');
 assert(calls.some(c=>c.path==='/threads/new/messages'&&JSON.parse(c.options.body).text==='First message without setup'));
 assert.equal(elements.draft.value,'');
 elements.draft.value='Keyboard message';
 let prevented=false;const keyBefore=calls.length;
 elements.draft.onkeydown({key:'Enter',shiftKey:true,isComposing:false,preventDefault(){prevented=true}});await settle();
 assert.equal(calls.length,keyBefore);assert.equal(prevented,false);
 elements.draft.onkeydown({key:'Enter',shiftKey:false,isComposing:true,preventDefault(){prevented=true}});await settle();assert.equal(calls.length,keyBefore);
 elements.draft.onkeydown({key:'Enter',shiftKey:false,isComposing:false,preventDefault(){prevented=true}});await settle();
 assert(prevented);assert(calls.some(c=>c.path==='/threads/new/messages'&&JSON.parse(c.options.body).text==='Keyboard message'));
 calls.length=0;
 assert.equal(elements.tree.children.length,2);elements.tree.children[1].onclick();await settle();
 assert.equal(elements.title.textContent,'Small task title');assert(elements.metadata.textContent.includes('child'));assert(elements.metadata.textContent.includes('fixture/model'));
 assert.equal(elements.transcript.children[0].children[1].textContent,'<img src=x onerror=bad()>');
 const detail=elements.transcript.querySelectorAll('details')[0];assert.equal(detail.dataset.id,'call-7');assert.equal(detail.dataset.type,'tool-call');detail.open=true;
 elements.draft.value='keep draft';await vm.runInContext('refresh()',sandbox);assert.equal(elements.draft.value,'keep draft');
 persistenceError='Disk full';await vm.runInContext('refresh()',sandbox);assert(elements.persistence.textContent.includes('Disk full'));persistenceError=null;await vm.runInContext('refresh()',sandbox);assert.equal(elements.persistence.textContent,'');
 vm.runInContext('refreshing=true',sandbox);elements.tree.children[0].onclick();assert.equal(elements.send.disabled,true);assert.equal(elements.cancel.disabled,true);assert.equal(elements.resume.disabled,true);assert.equal(elements.transcript.children.length,0);assert(elements.title.textContent.includes('Loading'));
 const before=calls.length;elements.compose.onsubmit({preventDefault(){}});assert.equal(calls.length,before);vm.runInContext('refreshing=false',sandbox);await vm.runInContext('refresh()',sandbox);assert.equal(elements.send.disabled,false);elements.tree.children[1].onclick();await settle();
 elements.draft.value='hello child';elements.behavior.value='followup';elements.compose.onsubmit({preventDefault(){}});await settle();
 const submit=calls.find(c=>c.path==='/threads/child/messages');assert.deepEqual(JSON.parse(submit.options.body),{text:'hello child',behavior:'followup'});
 elements.cancel.onclick();await settle();assert(calls.some(c=>c.path==='/threads/child/cancel'));
 archived=true;await vm.runInContext('refresh()',sandbox);assert.equal(elements.resume.disabled,false);elements.resume.onclick();await settle();assert(calls.some(c=>c.path==='/threads/child/resume'));
 elements.new.onclick();await settle();assert(calls.some(c=>c.path==='/threads/new'));
 console.log('Browser thread actions, safe text, typed details and draft preservation passed.');
})().catch(e=>{console.error(e);process.exitCode=1});
