local wheel = dofile("extensions/hue-shift/src/wheel.lua")

local expected = {
  {rgb={r=255,g=0,b=0},h=0,s=1},
  {rgb={r=0,g=255,b=0},h=120,s=1},
  {rgb={r=0,g=0,b=255},h=240,s=1},
  {rgb={r=255,g=255,b=0},h=60,s=1},
  {rgb={r=125,g=125,b=125},h=0,s=0}
}
for _,item in ipairs(expected) do
  local c = wheel.to_hsv(item.rgb)
  assert(math.abs(c.h-item.h)<1e-6)
  assert(math.abs(c.s-item.s)<1e-6)
  local dx,dy = wheel.position(item.rgb,80)
  assert(dx==dx and dy==dy)
  assert(dx*dx + dy*dy <= 80*80+1e-5)
end

for hue=0,359,15 do
  for _,sat in ipairs({0,0.15,0.5,1}) do
    for _,value in ipairs({0.25,0.75,1}) do
      local rgb = wheel.from_hsv(hue,sat,value)
      for _,key in ipairs({"r","g","b"}) do
        assert(rgb[key]>=0 and rgb[key]<=255)
      end
      local c = wheel.to_hsv(rgb)
      assert(math.abs(c.s-sat)<=0.025 or value<0.01)
      if sat>0.05 then
        local delta=math.abs((c.h-hue+540)%360-180)
        assert(delta<=3.1) -- integer RGB quantization can produce a 3 degree hue error
      end
    end
  end
end

local pixels=0
_G.ColorMode={ RGB=0 }
_G.Image=function(w,h,mode)
  assert(mode==0)
  return {
    width=w,height=h,
    drawPixel=function(_,x,y,color)
      assert(x>=0 and x<w and y>=0 and y<h)
      assert(type(color)=="table")
      pixels=pixels+1
    end
  }
end
_G.app={pixelColor={rgba=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end}}
local image=wheel.make_image(20)
assert(image.width==41 and image.height==41)
assert(pixels>1000 and pixels<41*41)

print("OK: HSV wheel conversion, position, and cached image (" .. pixels .. " pixels)")
