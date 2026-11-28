import { useMemo, useState } from 'react'
const themes={birthday:{emoji:'🎂'},anniversary:{emoji:'💞'}}
function draft(d){
 const n=d.name||'my favourite person',f=d.from||'Someone who loves you';
 const traits=d.description.split(/[,.\\n]+/).map(x=>x.trim()).filter(Boolean).slice(0,4);
 if(d.occasion==='birthday')return 'To '+n+',\\n\\nToday deserves extra sparkle because the world got you. I love '+(traits.length?traits.join(', ').toLowerCase():'your little ways of making ordinary moments special')+'. I hope this next chapter brings you big smiles, beautiful surprises and every little thing your heart has been wishing for.\\n\\nHappy Birthday. Keep being wonderfully you.\\n\\nWith all my love, '+f+' 💗';
 return 'To '+n+',\\n\\nAnother chapter, another collection of little moments I would not trade. I love '+(traits.length?traits.join(', ').toLowerCase():'the little things that make you, you')+'. Thank you for making the ordinary feel special and for being my favourite person to do life with.\\n\\nHere is to the memories we have made and all the ones still waiting for us. Happy Anniversary.\\n\\nAlways yours, '+f+' 💞'
}
export default function PremiumWishes(){
 const params=useMemo(()=>new URLSearchParams(location.search),[]);
 const shared=params.get('view')==='1';
 const [occasion,setOccasion]=useState(params.get('occasion')||'birthday');
 const [name,setName]=useState(params.get('name')||'');
 const [from,setFrom]=useState(params.get('from')||'');
 const [date,setDate]=useState(params.get('date')||'');
 const [years,setYears]=useState(params.get('years')||'');
 const [description,setDescription]=useState(params.get('description')||'');
 const [message,setMessage]=useState(params.get('message')||'');
 const [photo,setPhoto]=useState('');
 const [photoName,setPhotoName]=useState('');
 const [preview,setPreview]=useState(shared);
 const [copied,setCopied]=useState(false);
 const [error,setError]=useState('');
 const data={occasion,name:name.trim(),from:from.trim(),date,years,description:description.trim(),message:message.trim()};
 const finalMessage=message.trim()||draft(data);
 function upload(file){
  if(!file)return;
  if(!file.type.startsWith('image/')){setError('Please choose an image file.');return}
  if(file.size>8*1024*1024){setError('Choose a photo under 8 MB.');return}
  const reader=new FileReader();
  reader.onload=()=>{const img=new Image();img.onload=()=>{const scale=Math.min(1,1000/Math.max(img.width,img.height));const c=document.createElement('canvas');c.width=Math.round(img.width*scale);c.height=Math.round(img.height*scale);c.getContext('2d').drawImage(img,0,0,c.width,c.height);setPhoto(c.toDataURL('image/jpeg',.82));setPhotoName(file.name);setError('')};img.src=reader.result};
  reader.readAsDataURL(file)
 }
 function create(e){e.preventDefault();if(!data.name){setError('Add your person’s name first.');return}if(!data.description){setError('Tell us a few things you love about them.');return}setError('');setPreview(true);window.scrollTo({top:0,behavior:'smooth'})}
 async function share(){
  const p=new URLSearchParams({view:'1',occasion:data.occasion,name:data.name,from:data.from,date:data.date,years:data.years,description:data.description,message:data.message});
  const url=location.origin+'/premium-wishes/?'+p.toString();
  try{await navigator.clipboard.writeText(url);setCopied(true);setTimeout(()=>setCopied(false),2200)}catch{window.prompt('Copy your wish page link:',url)}
 }
 function edit(){setPreview(false);setError('');history.replaceState({},'',location.pathname);window.scrollTo({top:0,behavior:'smooth'})}
 if(preview)return <main className={'premium-page '+(occasion==='birthday'?'theme-birthday':'theme-anniversary')}>
  <section className="premium-preview-shell">
   <div className="premium-topline"><a href="/">♡ HeyCutu</a><span>PREMIUM WISH · PERSONAL EDITION</span></div>
   <header className="premium-hero"><span className="premium-sticker">{occasion==='birthday'?'A DAY MADE FOR YOU':'OUR LITTLE LOVE STORY'} ✦</span>
    <div className="premium-orbit" aria-hidden="true"><i>{themes[occasion].emoji}</i><b>♡</b><em>✦</em><small>✿</small></div>
    <p className="premium-script">{occasion==='birthday'?'To my favourite human':'To my favourite chapter'}</p>
    <h1>{occasion==='birthday'?'Happy Birthday,':'Happy Anniversary,'}<br/><em>{name||'my love'}!</em></h1>
    <p className="premium-sub">{occasion==='birthday'?'Today, the universe gets to celebrate you.':'Every year with you is my favourite plot twist.'}</p>
   </header>
   <div className="premium-marquee"><span>{themes[occasion].emoji} MADE WITH LOVE ✦ JUST FOR YOU ✦ {themes[occasion].emoji} MADE WITH LOVE ✦ JUST FOR YOU ✦</span></div>
   <section className="premium-memory-grid">
    <div className="premium-polaroid"><div className="premium-photo">{photo?<img src={photo} alt={'Photo of '+name}/>:<div className="premium-photo-placeholder"><span>{occasion==='birthday'?'📸':'💗'}</span><small>YOUR FAVOURITE MEMORY</small></div>}</div><p>{name} <span>♡</span></p><small>{date?new Date(date+'T12:00:00').toLocaleDateString(undefined,{day:'numeric',month:'long',year:'numeric'}):'A moment worth keeping'}</small></div>
    <article className="premium-letter"><span className="premium-tape">A NOTE FROM THE HEART</span><h2>{occasion==='birthday'?'A little letter for you':'A page from our story'}</h2><p>{finalMessage}</p><b>— {from||'Someone who adores you'} ✍️</b></article>
   </section>
   <section className="premium-traits"><p className="premium-script">The little things I adore</p><h2>You’re special in a million ways.</h2><div>{description.split(/[,.\\n]+/).map(x=>x.trim()).filter(Boolean).slice(0,8).map((x,i)=><span key={i}>{['✦','♡','✿','☀'][i%4]} {x}</span>)}</div></section>
   <section className="premium-ending"><div>{themes[occasion].emoji}</div><h2>{occasion==='birthday'?'Make a wish.':'Here’s to us.'}</h2><p>{occasion==='birthday'?'May this year be as lovely as the person you are.':'More laughs, more little adventures, more choosing each other.'}</p><strong>Forever cheering for you, {name} ♡</strong></section>
   <div className="premium-actions"><button className="btn" onClick={share}>{copied?'Link copied ✓':'Copy share link ↗'}</button><button className="btn soft" onClick={edit}>Edit my wish</button></div>
   <p className="premium-footnote">Made with a little extra love on HeyCutu · Photo stays in this preview on this device.</p>
  </section>
 </main>;
 return <main className="premium-page premium-builder">
  <section className="premium-builder-head"><a href="/">♡ HeyCutu</a><span>THE PREMIUM WISH STUDIO</span><h1>Make their day<br/><em>one to remember.</em></h1><p>A personal page, not just another greeting. Add their photo, tell us what makes them special, and create a little keepsake.</p></section>
  <section className="premium-builder-layout">
   <form className="premium-form" onSubmit={create}>
    <div className="premium-step"><small>01 / OCCASION</small><h2>What are we celebrating?</h2><div className="premium-choice">
     <button type="button" className={occasion==='birthday'?'selected':''} onClick={()=>setOccasion('birthday')}><span>🎂</span><b>Birthday</b><small>A whole day for them</small></button>
     <button type="button" className={occasion==='anniversary'?'selected':''} onClick={()=>setOccasion('anniversary')}><span>💞</span><b>Anniversary</b><small>Your story together</small></button>
    </div></div>
    <div className="premium-step"><small>02 / THE DETAILS</small><h2>Who is this for?</h2>
     <label>Their name<input value={name} onChange={e=>setName(e.target.value)} placeholder="e.g. Aisha" maxLength={50} required/></label>
     <label>Your name<input value={from} onChange={e=>setFrom(e.target.value)} placeholder="e.g. Rahul" maxLength={50}/></label>
     <label>{occasion==='birthday'?'Birthday date':'Your anniversary date'}<input type="date" value={date} onChange={e=>setDate(e.target.value)}/></label>
     {occasion==='anniversary'&&<label>How many years together? (optional)<input type="number" min="1" max="100" value={years} onChange={e=>setYears(e.target.value)} placeholder="e.g. 3"/></label>}
    </div>
    <div className="premium-step"><small>03 / THEIR PHOTO</small><h2>One picture. A thousand feelings.</h2><label className="premium-upload"><input type="file" accept="image/*" onChange={e=>upload(e.target.files?.[0])}/><span>📷</span><b>{photoName||'Upload their favourite photo'}</b><small>JPG, PNG or WEBP · up to 8 MB</small></label><p className="premium-privacy">🔒 Your photo is only used in this preview right now. Secure shareable photo storage will be connected after the design is approved.</p></div>
    <div className="premium-step"><small>04 / MAKE IT PERSONAL</small><h2>Describe your person.</h2>
     <label>What makes them them?<textarea value={description} onChange={e=>setDescription(e.target.value)} rows="4" maxLength={500} placeholder="Their laugh, their kindness, their love for chai, the way they remember tiny details…"/></label>
     <label>Your personal message (optional)<textarea value={message} onChange={e=>setMessage(e.target.value)} rows="4" maxLength={700} placeholder="Add your own words. Leave blank and we’ll write a heartfelt note using your description."/></label>
    </div>
    {error&&<p className="premium-error">{error}</p>}<button className="btn premium-submit" type="submit">Create my premium wish ↗</button><p className="premium-smallprint">Preview first · No payment is taken in this preview build.</p>
   </form>
   <aside className="premium-side-preview"><div className="premium-side-card"><span>YOUR LITTLE MASTERPIECE</span><div>{themes[occasion].emoji}</div><h2>{occasion==='birthday'?'A birthday they’ll remember':'A story worth celebrating'}</h2><p>{name?'Made especially for '+name+'.':'Your person’s name will appear here.'}</p><b>✦ A letter · Their photo · Little details ✦</b></div><p>Inspired by handmade scrapbook pages, playful doodles and the little details that make your relationship yours.</p></aside>
  </section>
 </main>
}
