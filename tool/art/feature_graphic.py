from PIL import Image, ImageDraw, ImageFont
W,H=1024,500
BG=(19,24,42); BAND=(43,52,84); RAIL=(72,84,140); YEL=(247,192,52); RED=(255,86,102); SUB=(133,146,196); BLK=(52,62,104)
im=Image.new("RGB",(W,H),BAND); d=ImageDraw.Draw(im)
top,bot=70,430
d.rectangle([0,top,W,bot],fill=BG)
for x in range(0,W,64): d.line([x,top,x,bot],fill=(26,32,54),width=1)
d.rectangle([0,top-6,W,top],fill=RAIL); d.rectangle([0,bot,W,bot+6],fill=RAIL)
# player on ceiling
px,py=250,top+2; d.rounded_rectangle([px,py,px+52,py+50],radius=10,fill=YEL); d.rectangle([px,py,px+52,py+12],fill=(196,146,30))
for ex in (px+18,px+34): d.ellipse([ex-6,py+28,ex+6,py+40],fill="white"); d.ellipse([ex-2,py+31,ex+3,py+37],fill=(30,30,40))
# spikes
def spike(x,up=True,s=48):
    if up: d.polygon([(x,bot),(x+s,bot),(x+s/2,bot-s*1.2)],fill=RED)
    else: d.polygon([(x,top),(x+s,top),(x+s/2,top+s*1.2)],fill=RED)
spike(600);spike(660);spike(800,False)
d.rectangle([880,bot-70,950,bot],fill=BLK)
font=lambda s: ImageFont.truetype("/work/repos/fliptide/assets/fonts/Inter-Variable.ttf",s)
f1=font(120); f1.set_variation_by_name("Bold") if hasattr(f1,"set_variation_by_name") else None
try: f1.set_variation_by_axes([32,800])
except Exception: pass
f2=font(30)
try: f2.set_variation_by_axes([32,600])
except Exception: pass
t="Fliptide"; bb=d.textbbox((0,0),t,font=f1); d.text(((W-bb[2]+bb[0])/2,150),t,font=f1,fill=YEL)
t2="one tap flips gravity · same course for everyone today"; bb=d.textbbox((0,0),t2,font=f2); d.text(((W-bb[2]+bb[0])/2,305),t2,font=f2,fill=SUB)
im.save("/work/repos/fliptide/docs/play-store/feature-graphic-1024x500.png",optimize=True)
print(im.size)
