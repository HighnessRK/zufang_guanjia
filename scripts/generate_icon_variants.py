from pathlib import Path
from PIL import Image, ImageDraw
root=Path('android/app/src/main/res')
palettes={'ocean':['0B9BE1','1258AA','57D5D5'],'sunset':['FFB76B','E97878','AF71BC'],'jade':['3DC9AC','278879','8EC9B9'],'mono':['657288','283345','121B28'],'lavender':['B49AEF','7565B6','D4BDF4'],'coral':['FF9C99','D76E87','FFC7AD'],'amber':['F4C96B','C58F47','EDB784']}
house='M21,46 L46,23 Q50,19 54,23 L79,46 Q82,50 78,53 L73,53 L73,74 Q73,80 67,80 L33,80 Q27,80 27,74 L27,53 L22,53 Q18,50 21,46 Z'
for style,colors in palettes.items():
 (root/f'drawable/icon_{style}_bg.xml').write_text(f'<shape xmlns:android="http://schemas.android.com/apk/res/android"><gradient android:angle="315" android:startColor="#{colors[0]}" android:centerColor="#{colors[1]}" android:endColor="#{colors[2]}" /></shape>')
 if style=='lavender':paths='<path android:fillColor="#EEFFFFFF" android:pathData="M42,20 A13.5,13.5 0,1 0,48,43 A13.5,13.5 0,0 1,42,20 Z M39,60 L73,60 L73,84 L39,84 Z"/><path android:fillColor="#00000000" android:strokeColor="#EEFFFFFF" android:strokeWidth="4" android:strokeLineJoin="round" android:pathData="M30,63 L57,39 L81,63"/>'
 elif style=='coral':paths='<path android:fillColor="#00000000" android:strokeColor="#EEFFFFFF" android:strokeWidth="4" android:strokeLineJoin="round" android:pathData="M38,24 L62,24 Q76,24 76,38 L76,62 Q76,76 62,76 L38,76 Q24,76 24,62 L24,38 Q24,24 38,24 Z M50,25 L50,75 M25,50 L75,50"/>'
 elif style=='amber':paths='<path android:fillColor="#EEFFFFFF" android:pathData="M28,80 L28,46 A22,22 0,0 1,72,46 L72,80 Z"/><path android:fillColor="#C58F47" android:pathData="M39,80 L39,55 A11.5,11.5 0,0 1,62,55 L62,80 Z"/><path android:fillColor="#FFFFFF" android:pathData="M58.5,64 A2.5,2.5 0,1 0,53.5,64 A2.5,2.5 0,1 0,58.5,64"/>'
 elif style=='ocean':paths='<path android:strokeColor="#E1F6FF" android:strokeWidth="6" android:strokeLineCap="round" android:fillColor="#00000000" android:pathData="M54,38 a15,15 0,1 0,-30 0 a15,15 0,1 0,30 0 M50,50 L73,73 M63,63 L70,56 M69,69 L76,62"/>'
 elif style=='sunset':
  paths='<path android:fillColor="#CCFFFFFF" android:pathData="M38,20 L63,20 Q72,20 72,29 L72,72 Q72,81 63,81 L38,81 Q29,81 29,72 L29,29 Q29,20 38,20 Z"/>'
  for r in range(3):
   for c in range(2):
    x,y=38+c*16,31+r*13;paths+=f'<path android:fillColor="#C97A89" android:pathData="M{x},{y} h8 v7 h-8 Z"/>'
  paths+='<path android:fillColor="#C97A89" android:pathData="M46,68 h10 v13 h-10 Z"/>'
 else:paths=f'<path android:fillColor="#{"00" if style=="mono" else "70"}EEF7FF" android:strokeColor="#DDFFFFFF" android:strokeWidth="2" android:strokeLineJoin="round" android:pathData="{house}"/><path android:fillColor="#AAFFFFFF" android:pathData="M43,55 h14 v25 h-14 Z"/>'
 (root/f'drawable/icon_{style}_fg.xml').write_text(f'<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="100" android:viewportHeight="100"><group android:pivotX="50" android:pivotY="50" android:scaleX="0.72" android:scaleY="0.72">{paths}</group></vector>')
 (root/f'mipmap-anydpi-v26/ic_launcher_{style}.xml').write_text(f'<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/icon_{style}_bg"/><foreground android:drawable="@drawable/icon_{style}_fg"/></adaptive-icon>')
 im=Image.new('RGBA',(400,400));px=im.load();rgb=[tuple(bytes.fromhex(c)) for c in colors]
 for y in range(400):
  for x in range(400):
   t=(x+y)/798*2;i=min(1,int(t));f=t-i;px[x,y]=tuple(round(rgb[i][j]*(1-f)+rgb[i+1][j]*f) for j in range(3))+(255,)
 layer=Image.new('RGBA',im.size);d=ImageDraw.Draw(layer)
 if style=='lavender':
  d.pieslice((84,80,192,188),80,340,fill=(255,255,255,238));d.line((120,252,228,156,324,252),fill='white',width=16);d.rounded_rectangle((156,240,292,336),radius=20,fill=(255,255,255,225))
 elif style=='coral':
  d.rounded_rectangle((96,96,304,304),radius=56,outline='white',width=16);d.line((200,100,200,300),fill='white',width=16);d.line((100,200,300,200),fill='white',width=16)
 elif style=='amber':
  d.rounded_rectangle((112,96,288,384),radius=88,fill=(255,255,255,225));d.rectangle((112,184,288,320),fill=(255,255,255,225));d.rectangle((112,321,288,399),fill=(0,0,0,0));d.rounded_rectangle((156,176,248,370),radius=46,fill='#C58F47');d.rectangle((156,250,248,320),fill='#C58F47');d.rectangle((156,321,248,399),fill=(0,0,0,0));d.ellipse((214,246,234,266),fill='white')
 elif style=='ocean':
  d.ellipse((96,92,216,212),outline='#E1F6FF',width=24);d.line((200,200,292,292),fill='#E1F6FF',width=24);d.line((252,252,280,224),fill='#E1F6FF',width=24);d.line((276,276,304,248),fill='#E1F6FF',width=24)
 elif style=='sunset':
  d.rounded_rectangle((116,80,288,324),radius=36,fill=(255,255,255,221))
  for r in range(3):
   for c in range(2):
    x,y=(38+c*16)*4,(31+r*13)*4;d.rounded_rectangle((x,y,x+32,y+28),radius=8,fill='#C97A89')
  d.rounded_rectangle((184,272,224,324),radius=12,fill='#C97A89')
 else:
  poly=[(84,184),(200,84),(316,184),(292,212),(292,320),(108,320),(108,212)];d.polygon(poly,fill=(238,247,255,0 if style=='mono' else 100));d.line(poly+[poly[0]],fill='white',width=8,joint='curve');d.rounded_rectangle((172,220,228,320),radius=20,fill=(255,255,255,180))
 im=Image.alpha_composite(im,layer);mask=Image.new('L',im.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,399,399),radius=104,fill=255);im.putalpha(mask)
 for density,n in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]: im.resize((n,n),Image.Resampling.LANCZOS).save(root/f'mipmap-{density}/ic_launcher_{style}.png')
