/* マークシート：シートの作成と写真からの読み取り（外部サーバーなし・スマホの中だけで処理） */
(function(){
var W=1240,H=1754;               // A4・150dpi相当の座標
var FID=60;                       // 四隅の目印（黒い四角）の一辺
var FC=[[90,90],[W-90,90],[W-90,H-90],[90,H-90]]; // 目印の中心（左上・右上・右下・左下）
var NB=15,R=15,BX0=560,BSP=40,GAP=14; // 1行の丸の数・半径・位置
var IDBITS=12;

function hash12(str){var h=2166136261;for(var i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,16777619)>>>0}return (h^(h>>>12)^(h>>>24))&4095}

function layout(rows){
  var top=300,bottom=H-200,n=Math.max(1,rows.length);
  var rh=Math.min(66,Math.max(40,Math.floor((bottom-top)/n)));
  var out=rows.slice(0,Math.floor((bottom-top)/40)).map(function(r,i){
    var cy=top+rh*i+rh/2,bs=[];
    for(var j=0;j<NB;j++)bs.push([BX0+j*BSP+Math.floor(j/5)*GAP,cy]);
    return {i:r.i,s:r.s||null,label:r.label,unit:r.unit||'',yen:!!r.yen,y:cy,h:rh,bubbles:bs};
  });
  var id=hash12(out.map(function(r){return r.i+'|'+(r.s||'')}).join(','));
  var bits=[];for(var b=0;b<IDBITS;b++)bits.push([300+b*52,H-90]);
  return {rows:out,id:id,bits:bits,truncated:out.length<rows.length};
}

function drawSheet(cv,L,meta){
  cv.width=W;cv.height=H;var c=cv.getContext('2d');
  c.fillStyle='#fff';c.fillRect(0,0,W,H);
  c.fillStyle='#000';FC.forEach(function(p){c.fillRect(p[0]-FID/2,p[1]-FID/2,FID,FID)});
  var F='"Hiragino Sans","Noto Sans JP","Noto Sans CJK JP",sans-serif';
  c.fillStyle='#111';c.textBaseline='middle';
  c.font='bold 38px '+F;c.fillText('成果マークシート',150,92);
  c.font='26px '+F;c.fillText('名前：'+(meta.name||'＿＿＿＿＿＿'),150,160);
  c.fillText('日付：＿＿月＿＿日',620,160);
  c.font='22px '+F;c.fillStyle='#444';
  c.fillText('1件売れるごとに、左から順に丸を1つ塗りつぶしてください（黒のペンでしっかり）。',150,215);
  c.fillText('撮影は明るい所で、四すみの黒い四角が全部入るように。',150,250);
  // 表
  L.rows.forEach(function(r,i){
    if(i%2===0){c.fillStyle='#f3f4f6';c.fillRect(70,r.y-r.h/2,W-140,r.h)}
    c.fillStyle='#111';c.font='bold '+Math.min(26,r.h*0.42)+'px '+F;
    var lab=r.label;while(c.measureText(lab).width>440&&lab.length>2)lab=lab.slice(0,-2)+'…';
    c.fillText(lab,82,r.y-(r.yen?9:0));
    if(r.yen){c.font=Math.min(17,r.h*0.3)+'px '+F;c.fillStyle='#666';c.fillText('金額は読み取り後に入力',82,r.y+15)}
    r.bubbles.forEach(function(b,j){
      c.beginPath();c.arc(b[0],b[1],R,0,Math.PI*2);c.fillStyle='#fff';c.fill();
      c.lineWidth=2;c.strokeStyle='#9ca3af';c.stroke();
      c.fillStyle='#c4c8cf';c.font='13px '+F;c.textAlign='center';c.fillText(String(j+1),b[0],b[1]+1);c.textAlign='left';
    });
  });
  // シートID（項目が変わっていないかの確認用）
  c.fillStyle='#000';
  L.bits.forEach(function(p,b){if((L.id>>b)&1)c.fillRect(p[0]-12,p[1]-12,24,24);else{c.strokeStyle='#d1d5db';c.lineWidth=1;c.strokeRect(p[0]-12,p[1]-12,24,24)}});
  c.fillStyle='#888';c.font='18px '+F;c.fillText('シートID '+L.id,960,H-90);
  if(L.truncated){c.fillStyle='#b91c1c';c.font='20px '+F;c.fillText('※項目が多いため一部をのせていません',150,H-150)}
}

// ---- 読み取り ----
function solve(A,b){var n=b.length;for(var i=0;i<n;i++){var m=i;for(var k=i+1;k<n;k++)if(Math.abs(A[k][i])>Math.abs(A[m][i]))m=k;
  var t=A[i];A[i]=A[m];A[m]=t;t=b[i];b[i]=b[m];b[m]=t;if(Math.abs(A[i][i])<1e-12)return null;
  for(var k2=i+1;k2<n;k2++){var f=A[k2][i]/A[i][i];for(var j=i;j<n;j++)A[k2][j]-=f*A[i][j];b[k2]-=f*b[i]}}
  var x=new Array(n);for(var i2=n-1;i2>=0;i2--){var s=b[i2];for(var j2=i2+1;j2<n;j2++)s-=A[i2][j2]*x[j2];x[i2]=s/A[i2][i2]}return x}
function homography(src,dst){var A=[],b=[];for(var i=0;i<4;i++){var x=src[i][0],y=src[i][1],u=dst[i][0],v=dst[i][1];
  A.push([x,y,1,0,0,0,-u*x,-u*y]);b.push(u);A.push([0,0,0,x,y,1,-v*x,-v*y]);b.push(v)}
  var h=solve(A,b);if(!h)return null;h.push(1);return h}
function apply(h,x,y){var w=h[6]*x+h[7]*y+h[8];return[(h[0]*x+h[1]*y+h[2])/w,(h[3]*x+h[4]*y+h[5])/w]}

function toGray(img,maxDim){
  var s=Math.min(1,maxDim/Math.max(img.width,img.height)),w=Math.round(img.width*s),h=Math.round(img.height*s);
  var cv=document.createElement('canvas');cv.width=w;cv.height=h;var c=cv.getContext('2d');c.drawImage(img,0,0,w,h);
  var d=c.getImageData(0,0,w,h).data,g=new Float32Array(w*h);
  for(var i=0,p=0;i<g.length;i++,p+=4)g[i]=0.299*d[p]+0.587*d[p+1]+0.114*d[p+2];
  return{g:g,w:w,h:h};
}
function findFiducials(G){
  var w=G.w,h=G.h,g=G.g,I=new Float64Array((w+1)*(h+1));
  for(var y=0;y<h;y++){var row=0;for(var x=0;x<w;x++){row+=g[y*w+x];I[(y+1)*(w+1)+x+1]=I[y*(w+1)+x+1]+row}}
  var r=Math.max(8,Math.round(Math.min(w,h)/14)),bin=new Uint8Array(w*h);
  for(var y2=0;y2<h;y2++){var y0=Math.max(0,y2-r),y1=Math.min(h,y2+r+1);for(var x2=0;x2<w;x2++){var x0=Math.max(0,x2-r),x1=Math.min(w,x2+r+1);
    var m=(I[y1*(w+1)+x1]-I[y0*(w+1)+x1]-I[y1*(w+1)+x0]+I[y0*(w+1)+x0])/((y1-y0)*(x1-x0));
    bin[y2*w+x2]=(g[y2*w+x2]<m*0.72&&g[y2*w+x2]<150)?1:0}}
  var lab=new Int32Array(w*h),cands=[],st=new Int32Array(w*h),minD=Math.min(w,h);
  for(var p=0;p<w*h;p++){if(!bin[p]||lab[p])continue;var n=0,sp=0,minx=1e9,maxx=-1,miny=1e9,maxy=-1,sx=0,sy=0;
    st[sp++]=p;lab[p]=1;
    while(sp){var q=st[--sp],qx=q%w,qy=(q/w)|0;n++;sx+=qx;sy+=qy;if(qx<minx)minx=qx;if(qx>maxx)maxx=qx;if(qy<miny)miny=qy;if(qy>maxy)maxy=qy;
      if(qx>0&&bin[q-1]&&!lab[q-1]){lab[q-1]=1;st[sp++]=q-1}if(qx<w-1&&bin[q+1]&&!lab[q+1]){lab[q+1]=1;st[sp++]=q+1}
      if(qy>0&&bin[q-w]&&!lab[q-w]){lab[q-w]=1;st[sp++]=q-w}if(qy<h-1&&bin[q+w]&&!lab[q+w]){lab[q+w]=1;st[sp++]=q+w}}
    var bw=maxx-minx+1,bh=maxy-miny+1;
    if(bw<minD*0.012||bh<minD*0.012||bw>minD*0.2||bh>minD*0.2)continue;
    var asp=bw/bh;if(asp<0.55||asp>1.8)continue;var fill=n/(bw*bh);if(fill<0.6)continue;
    cands.push({x:sx/n,y:sy/n,a:n,fill:fill});}
  cands.sort(function(a,b){return b.a-a.a});cands=cands.slice(0,14);
  var best=null,bs=-1;
  for(var a=0;a<cands.length;a++)for(var b=a+1;b<cands.length;b++)for(var c=b+1;c<cands.length;c++)for(var d=c+1;d<cands.length;d++){
    var P=[cands[a],cands[b],cands[c],cands[d]],areas=P.map(function(o){return o.a}),mx=Math.max.apply(0,areas),mn=Math.min.apply(0,areas);
    if(mn/mx<0.35)continue;
    var o=order(P);if(!o)continue;var ar=quadArea(o);if(ar<w*h*0.08)continue;
    var top=dist(o[0],o[1]),bot=dist(o[3],o[2]),lef=dist(o[0],o[3]),rig=dist(o[1],o[2]);
    var ratio=((lef+rig)/2)/((top+bot)/2),want=(H-180)/(W-180);
    if(Math.abs(ratio-want)/want>0.45)continue;
    var sc=ar*(mn/mx)*P.reduce(function(s,o2){return s+o2.fill},0);
    if(sc>bs){bs=sc;best=o}}
  return best;
}
function dist(a,b){return Math.hypot(a.x-b.x,a.y-b.y)}
function order(P){var cx=0,cy=0;P.forEach(function(p){cx+=p.x;cy+=p.y});cx/=4;cy/=4;
  var s=P.slice().sort(function(a,b){return Math.atan2(a.y-cy,a.x-cx)-Math.atan2(b.y-cy,b.x-cx)});
  // atan2順（-π→π）：左上(-135°)・右上(-45°)・右下(45°)・左下(135°)
  var tl=0,bi=1e18;s.forEach(function(p,i){var v=p.x+p.y;if(v<bi){bi=v;tl=i}});
  var o=[s[tl],s[(tl+1)%4],s[(tl+2)%4],s[(tl+3)%4]];
  if(o[1].x<o[0].x)return null;return o}
function quadArea(o){var a=0;for(var i=0;i<4;i++){var p=o[i],q=o[(i+1)%4];a+=p.x*q.y-q.x*p.y}return Math.abs(a)/2}

function sampleAt(G,x,y){var xi=Math.round(x),yi=Math.round(y);if(xi<0||yi<0||xi>=G.w||yi>=G.h)return 255;return G.g[yi*G.w+xi]}
function readBubble(G,h,cx,cy,rad){
  var inner=[],ring=[],k=rad/R;
  for(var dy=-rad;dy<=rad;dy+=rad/7)for(var dx=-rad;dx<=rad;dx+=rad/7){var rr=Math.hypot(dx,dy);
    if(rr<=rad*0.58){var p=apply(h,cx+dx,cy+dy);inner.push(sampleAt(G,p[0],p[1]))}}
  for(var a=0;a<24;a++){var t=a/24*Math.PI*2;[1.25,1.42].forEach(function(f){var p=apply(h,cx+Math.cos(t)*rad*f,cy+Math.sin(t)*rad*f);ring.push(sampleAt(G,p[0],p[1]))})}
  ring.sort(function(a,b){return a-b});var paper=ring[Math.floor(ring.length*0.75)];
  var dark=0;inner.forEach(function(v){if(v<paper*0.68)dark++});
  return{ratio:dark/inner.length,paper:paper};
}

function read(img,L){
  var G=toGray(img,1800);
  var f=findFiducials(G);
  if(!f)return{ok:false,reason:'四すみの黒い四角が見つかりませんでした。シート全体が写るように、明るい所で真上から撮り直してください。'};
  var h=homography(FC,f.map(function(p){return[p.x,p.y]}));
  if(!h)return{ok:false,reason:'シートの向きがうまく読めませんでした。撮り直してください。'};
  var rows=L.rows.map(function(r){var marks=r.bubbles.map(function(b){return readBubble(G,h,b[0],b[1],R).ratio});
    var cnt=0;marks.forEach(function(v){if(v>0.42)cnt++});
    var unsure=marks.some(function(v){return v>0.22&&v<=0.42});
    return{i:r.i,s:r.s,label:r.label,unit:r.unit,yen:r.yen,count:cnt,marks:marks,unsure:unsure}});
  var id=0,idDark=[];L.bits.forEach(function(p,b){var v=readBubble(G,h,p[0],p[1],12).ratio;idDark.push(v);if(v>0.5)id|=(1<<b)});
  return{ok:true,rows:rows,idMatch:id===L.id,readId:id,preview:rectify(G,h,rows,L)};
}
function rectify(G,h,rows,L){
  var s=0.5,w=Math.round(W*s),hh=Math.round(H*s),cv=document.createElement('canvas');cv.width=w;cv.height=hh;
  var c=cv.getContext('2d'),im=c.createImageData(w,hh),d=im.data;
  for(var y=0;y<hh;y++)for(var x=0;x<w;x++){var p=apply(h,x/s,y/s),v=sampleAt(G,p[0],p[1]),o=(y*w+x)*4;d[o]=d[o+1]=d[o+2]=v;d[o+3]=255}
  c.putImageData(im,0,0);
  rows.forEach(function(r,i){var lr=L.rows[i];lr.bubbles.forEach(function(b,j){var m=r.marks[j];
    c.beginPath();c.arc(b[0]*s,b[1]*s,R*s+3,0,Math.PI*2);c.lineWidth=2.5;
    c.strokeStyle=m>0.42?'#16a34a':(m>0.22?'#f59e0b':'rgba(0,0,0,0)');c.stroke()})});
  return cv;
}

window.OMR={layout:layout,drawSheet:drawSheet,read:read,W:W,H:H};
})();
