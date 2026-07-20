from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, filename, bg_color="#0F1219", fg_color="#66FCF1"):
    img = Image.new('RGBA', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Draw a stylized monitor
    margin = size * 0.15
    monitor_rect = [margin, margin, size - margin, size - margin * 1.5]
    draw.rounded_rectangle(monitor_rect, radius=size*0.05, outline=fg_color, width=int(size*0.05))
    
    # Draw a stand
    stand_base = [size * 0.35, size - margin * 1.1, size * 0.65, size - margin * 0.9]
    draw.rectangle(stand_base, fill=fg_color)
    
    stand_neck = [size * 0.45, size - margin * 1.5, size * 0.55, size - margin * 1.1]
    draw.rectangle(stand_neck, fill=fg_color)
    
    # Draw an R or a lightning bolt inside
    inner_margin = margin * 2
    inner_rect = [inner_margin, inner_margin * 0.8, size - inner_margin, size - margin * 1.5 - margin * 0.5]
    
    # Drawing an "R" using lines
    w = size
    # vertical line
    draw.line([w*0.35, w*0.35, w*0.35, w*0.65], fill=fg_color, width=int(w*0.04))
    # loop
    draw.arc([w*0.35, w*0.35, w*0.65, w*0.5], start=-90, end=90, fill=fg_color, width=int(w*0.04))
    # leg
    draw.line([w*0.45, w*0.5, w*0.65, w*0.65], fill=fg_color, width=int(w*0.04))

    os.makedirs(os.path.dirname(filename), exist_ok=True)
    img.save(filename)

sizes = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192
}

base_dir = "android/app/src/main/res"

for density, size in sizes.items():
    create_icon(size, f"{base_dir}/mipmap-{density}/ic_launcher.png")
    # create a round one too
    create_icon(size, f"{base_dir}/mipmap-{density}/ic_launcher_round.png")

# Also create the Play Store icon (512x512)
create_icon(512, "android/app/src/main/ic_launcher-web.png")

print("Icons generated successfully!")
