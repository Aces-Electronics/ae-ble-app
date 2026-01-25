import sys
from PIL import Image

def add_padding(input_path, output_path, padding_percent=0.2):
    try:
        img = Image.open(input_path).convert("RGBA")
        width, height = img.size
        
        # Calculate new size (original size - padding)
        # padding_percent is total reduction, so each side reduces by half of that?
        # User said "shrink content by about 20%".
        # So new_content_size = original_size * 0.8
        
        scale_factor = 1.0 - padding_percent
        new_width = int(width * scale_factor * 0.9) # 10% narrower
        new_height = int(height * scale_factor)
        
        # Resize the image content
        resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Create a new blank image with the original size
        new_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        
        # Paste the resized content in the center
        paste_x = (width - new_width) // 2
        paste_y = (height - new_height) // 2
        
        new_img.paste(resized_img, (paste_x, paste_y), resized_img)
        
        new_img.save(output_path)
        print(f"Successfully saved padded image to {output_path}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    add_padding("assets/app_icon.png", "assets/app_icon_padded.png", padding_percent=0.35)
