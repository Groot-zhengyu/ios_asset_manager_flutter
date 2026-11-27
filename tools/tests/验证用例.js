/* 升级验证：日期清洗 + 三种基准来源 + 单行异常容错 + 性能一致性 */
const {JSDOM,VirtualConsole}=require('jsdom');
const fs=require('fs');
const path=require('path');
const html=fs.readFileSync(path.join(__dirname,'..','检察数据工作台_精炼版.html'),'utf8');
const vc=new VirtualConsole();
const errs=[];
vc.on('jsdomError',e=>errs.push('jsdomError: '+e.message));
vc.on('error',(...a)=>errs.push('console.error: '+a.join(' ')));
const dom=new JSDOM(html,{runScripts:'dangerously',pretendToBeVisual:true,virtualConsole:vc});
const w=dom.window;
let pass=0,fail=0;
function chk(name,got,exp){
  const g=JSON.stringify(got),e=JSON.stringify(exp);
  if(g===e){pass++;}else{fail++;console.log('FAIL',name,'got=',g,'exp=',e);}
}
function ok(name,cond,info){ if(cond){pass++;}else{fail++;console.log('FAIL',name,info===undefined?'':info);} }
function mkId(birth,seq){
  const base='110105'+birth+seq,wt=[7,9,10,5,8,4,2,1,6,3,7,9,10,5,8,4,2],cd='10X98765432';
  let s=0;for(let i=0;i<17;i++)s+=parseInt(base[i],10)*wt[i];
  return base+cd[s%11];
}
setTimeout(()=>{
  const E=w.DWB,S=E.state,$=id=>w.document.getElementById(id);
  ok('页面无脚本异常',errs.length===0,errs.slice(0,3).join(' | '));
  ok('DWB 已就绪',!!E&&!!S);

  /* ========== 1. 日期时间解析 ========== */
  const dt=(v,f)=>E.parseDateTime(v,f);
  chk('日期时间-紧凑带秒',dt('20260307 12:34:56').value,'2026-03-07');
  chk('日期时间-横杠带分',dt('2026-03-07 12:34').value,'2026-03-07');
  chk('日期时间-中文',dt('2026年3月7日 12:34:56').value,'2026-03-07');
  chk('日期时间-斜杠单数',dt('2026/3/7 1:2:3').value,'2026-03-07');
  chk('日期时间-ISO T',dt('2026-03-07T12:34:56Z').value,'2026-03-07');
  chk('日期时间-时区',dt('2026-03-07T12:34:56+08:00').value,'2026-03-07');
  chk('日期时间-纯日期',dt('20260307').value,'2026-03-07');
  chk('日期时间-空格输出',dt('20260307 12:34:56','space').value,'2026 03 07');
  chk('日期时间-紧凑输出',dt('20260307 12:34:56','compact').value,'20260307');
  chk('日期时间-中文输出',dt('20260307 12:34:56','cn').value,'2026年3月7日');
  chk('日期时间-斜杠输出',dt('20260307 12:34:56','slash').value,'2026/03/07');
  chk('日期时间-非法日',dt('20260230 12:00:00').ok,false);
  chk('日期时间-空值',dt('').empty,true);
  chk('日期时间-乱文',dt('abcdef').ok,false);
  chk('日期样式-8位编号不误判',E.looksLikeDateTime('12345678'),false);
  chk('日期样式-8位非法日仍识别',E.looksLikeDateTime('20260230'),true);

  /* ========== 2. 清洗规则 ========== */
  const id1=mkId('19850307','123');
  S.clean.srcHeaders=['日期时间','单据号','姓名'];
  S.clean.srcRows=[
    ['20260307 12:34:56','123456','张三'],
    ['2026-03-08 09:00:00','234567','李四'],
    ['20260230 12:00:00','345678','王五'],
    ['','456789','赵六'],
    ['２０２６０３０９ １２：００：００','567890','钱七']
  ];
  S.clean.srcHeaders.slice(); S.clean.loaded=true;
  $('r-date').checked=true; $('dateCleanFmt').value='iso';
  const st=E.applyCleaning();
  chk('清洗-日期列1',S.clean.rows[0][0],'2026-03-07');
  chk('清洗-日期列2',S.clean.rows[1][0],'2026-03-08');
  chk('清洗-非法日保留原值',S.clean.rows[2][0],'20260230 12:00:00');
  chk('清洗-非法日标红',!!S.clean.bad['2_0'],true);
  chk('清洗-空值保留',S.clean.rows[3][0],'');
  chk('清洗-全角日期',S.clean.rows[4][0],'2026-03-09');
  chk('清洗-8位编号不被改',S.clean.rows[2][1],'345678');
  ok('清洗-命中日期规则',(st.byRule.date||0)>=3,st.byRule.date);
  ok('清洗-记录异常',st.invalid>=1,st.invalid);
  // 关闭日期规则后不应转换
  $('r-date').checked=false;
  const st2=E.applyCleaning();
  chk('清洗-关闭规则不转换',S.clean.rows[0][0],'20260307 12:34:56');
  $('r-date').checked=true;

  /* ========== 3. 三种基准来源 ========== */
  const id2=mkId('19900101','124');
  function baseP(rows,rules,extra){
    const P={headers:['身份证号','基准日','案号'],rows:rows,rules:rules,baseMode:extra&&extra.mode||'manual'};
    if(extra&&extra.col!==undefined) P.baseCol=extra.col;
    return P;
  }
  const ageRule={op:'id_age',field:'身份证号',name:'年龄',params:{}};
  const yearRule={op:'case_year',field:'案号',name:'年份',params:{}};
  // 手动：与原逻辑完全一致
  let P=baseP([[id1,'2026-03-07','（2026）京0105刑初1号'],[id2,'2026-03-07','（2025）京0105刑初2号']],[ageRule,yearRule]);
  let R=E.runProcess(P,{y:2026,m:11,d:25});
  chk('手动-年龄1',R.rows[0][3],'41');
  chk('手动-年龄2',R.rows[1][3],'36');
  chk('手动-案号年份',R.rows[0][4],'2026');
  chk('手动-无异常',R.issueCount,0);
  // 表格日期列：逐行
  P=baseP([
    [id1,'2026-03-06','（2026）京0105刑初1号'],
    [id1,'2026-03-07','（2026）京0105刑初1号'],
    [id2,'2026-11-25','（2026）京0105刑初1号']
  ],[ageRule,yearRule],{mode:'column',col:'基准日'});
  R=E.runProcess(P,{y:1900,m:1,d:1});
  chk('逐行-生日前一天',R.rows[0][3],'40');
  chk('逐行-生日当天',R.rows[1][3],'41');
  chk('逐行-另一人',R.rows[2][3],'36');
  chk('逐行-案号年份不受影响',R.rows[0][4],'2026');
  chk('逐行-基准模式',R.baseMode,'column');
  // 非法/空基准日：留空+记录，其他行继续
  P=baseP([
    [id1,'2026-03-07','（2026）京0105刑初1号'],
    [id1,'','（2026）京0105刑初1号'],
    [id1,'2026-02-30','（2026）京0105刑初1号'],
    [id1,'2026-03-08','（2026）京0105刑初1号']
  ],[ageRule,{op:'id_birth',field:'身份证号',name:'出生日期',params:{}}],{mode:'column',col:'基准日'});
  R=E.runProcess(P,{y:2026,m:11,d:25});
  chk('异常基准-行1',R.rows[0][3],'41');
  chk('异常基准-空值留空',R.rows[1][3],'');
  chk('异常基准-非法留空',R.rows[2][3],'');
  chk('异常基准-行4继续',R.rows[3][3],'41');
  chk('异常基准-不相关列仍计算',R.rows[1][4],'1985-03-07');
  chk('异常基准-记录数',R.issueCount,2);
  chk('异常基准-回退行数',R.fallbackRows,2);
  // 日期列缺失：整体回退不中断
  P=baseP([[id1,'2026-03-07','（2026）京0105刑初1号']],[ageRule],{mode:'column',col:'不存在的列'});
  R=E.runProcess(P,{y:2026,m:11,d:25});
  chk('缺列-回退后年龄',R.rows[0][3],'41');
  ok('缺列-有回退提示',!!R.baseWarning,R.baseWarning);
  // 未指定列
  P=baseP([[id1,'2026-03-07','（2026）京0105刑初1号']],[ageRule],{mode:'column'});
  R=E.runProcess(P,{y:2026,m:11,d:25});
  chk('未指定列-回退后年龄',R.rows[0][3],'41');
  ok('未指定列-有回退提示',!!R.baseWarning);
  // 始终今天
  const today=E.baseToday();
  P=baseP([[id1,'2026-03-07','（2026）京0105刑初1号']],[ageRule],{mode:'today'});
  R=E.runProcess(P,{y:1900,m:1,d:1});
  chk('今天模式-结果',R.rows[0][3],String(E.ageOn({y:1985,m:3,d:7},today)));
  // 重名列保持一致
  P={headers:['身份证号','年龄'],rows:[[id1,'30']],rules:[{op:'id_age',field:'身份证号',name:'年龄',params:{}}]};
  R=E.runProcess(P,{y:2026,m:11,d:25});
  chk('重名列',R.headers,['身份证号','年龄','年龄_1']);
  chk('重名列值',R.rows[0][2],'41');
  // 逐行日期列支持合法格式差异
  P=baseP([
    [id1,'20260307 12:34:56','（2026）京0105刑初1号'],
    [id1,'2026年3月8日','（2026）京0105刑初1号']
  ],[ageRule],{mode:'column',col:'基准日'});
  R=E.runProcess(P,{y:2026,m:11,d:25});
  chk('逐行-日期格式差异1',R.rows[0][3],'41');
  chk('逐行-日期格式差异2',R.rows[1][3],'41');

  /* ========== 4. 界面联动 ========== */
  S.clean.loaded=true; S.clean.headers=['身份证号','基准日','案号'];
  S.clean.rows=[[id1,'2026-03-07','（2026）京0105刑初1号'],[id1,'','（2026）京0105刑初2号']];
  $('procSource').value='clean'; $('procSource').dispatchEvent(new w.Event('change'));
  $('procBaseMode').value='column'; $('procBaseMode').dispatchEvent(new w.Event('change'));
  ok('界面-日期列选择区显示',$('procBaseColWrap').style.display!=='none');
  ok('界面-日期列候选已填充',$('procBaseCol').options.length>=2,$('procBaseCol').innerHTML.slice(0,120));
  $('procBaseCol').value='基准日';
  $('procOp').value='id_age'; $('procOp').dispatchEvent(new w.Event('change'));
  $('procField').value='身份证号';
  $('btn-add-rule').click();
  $('btn-proc-run').click();
  const U=S.process.result;
  ok('界面-已执行处理',!!U);
  if(U){
    chk('界面-逐行结果',U.rows[0][3],'41');
    chk('界面-异常行留空',U.rows[1][3],'');
    ok('界面-异常提示框可见',$('procIssueBox').className.indexOf('show')>=0,$('procIssueBox').className);
  }
  $('procBaseMode').value='today'; $('procBaseMode').dispatchEvent(new w.Event('change'));
  ok('界面-今天模式隐藏日期列',$('procBaseColWrap').style.display==='none');
  $('procBase').value='2026-03-07'; $('procBase').dispatchEvent(new w.Event('change'));
  chk('界面-改日期自动切回手动',$('procBaseMode').value,'manual');
  ok('手册含新规则',(w.__MANUAL_HTML__||'').indexOf('日期时间 → 标准日期')>=0);
  ok('手册含逐行基准',(w.__MANUAL_HTML__||'').indexOf('表格日期列')>=0);

  /* ========== 5. 大批量性能与结果一致性 ========== */
  const N=20000;
  const bigRows=new Array(N);
  for(let i=0;i<N;i++){
    const birth=i%2?'19900101':'19850307';
    bigRows[i]=[mkId(birth,'123'),i%7===0?'':'2026-03-07','（2026）京0105刑初'+(i+1)+'号'];
  }
  const bigP={headers:['身份证号','基准日','案号'],rows:bigRows,rules:[
    {op:'id_birth',field:'身份证号',name:'出生日期',params:{}},
    {op:'id_age',field:'身份证号',name:'年龄',params:{}},
    {op:'date_fmt',field:'基准日',name:'标准日期',params:{fmt:'iso'}},
    {op:'case_year',field:'案号',name:'年份',params:{}},
    {op:'date_diff',field:'基准日',name:'距基准日',params:{}}
  ],baseMode:'column',baseCol:'基准日'};
  const t0=Date.now();
  const BR=E.runProcess(bigP,{y:2026,m:11,d:25});
  const ms=Date.now()-t0;
  ok('大批量-行数',BR.rows.length===N,BR.rows.length);
  chk('大批量-列数',BR.cols,5);
  chk('大批量-首行年龄',BR.rows[2][4],'41');
  chk('大批量-首行出生',BR.rows[2][3],'1985-03-07');
  chk('大批量-末行年份',BR.rows[N-1][6],'2026');
  chk('大批量-异常记录',BR.issueCount,Math.ceil(N/7));
  console.log('大批量 20000 行 × 5 规则耗时:',ms+'ms');
  ok('大批量-耗时可接受',ms<12000,ms);

  console.log('\n=== 结果: '+pass+' PASS, '+fail+' FAIL ===');
  console.log('运行期异常:',errs.length?errs.slice(0,3).join(' | '):'(无)');
  process.exit(fail?1:0);
},700);
