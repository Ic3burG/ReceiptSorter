from PIL import Image, ImageDraw

def create_icon(size):
    # Create a transparent background
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    padding = size // 10
    rect_size = size - (padding * 2)
    
    # Draw Apple-style rounded rect (Squircle approximation)
    # Background: Gemini Blue
    bg_color = (37, 99, 235)  # Tailwind blue-600
    corner_radius = size // 5
    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill=bg_color
    )
    
    # Draw Receipt Paper
    receipt_w = size // 3
    receipt_h = size // 2
    receipt_x = (size - receipt_w) // 2
    receipt_y = (size - receipt_h) // 2 + (size // 20)
    
    # Paper shadow/depth
    draw.rectangle(
        [receipt_x, receipt_y, receipt_x + receipt_w, receipt_y + receipt_h],
        fill=(255, 255, 255)
    )
    
    # Draw "Text" lines on receipt
    line_padding = receipt_w // 5
    for i in range(1, 5):
        line_y = receipt_y + (i * receipt_h // 6)
        line_w = receipt_w - (line_padding * 2)
        if i == 4: line_w //= 2 # Total line is shorter
        draw.line(
            [receipt_x + line_padding, line_y, receipt_x + line_padding + line_w, line_y],
            fill=(200, 200, 200),
            width=size // 100
        )

    # Draw Gemini Sparkle (top right of receipt)
    spark_size = size // 8
    spark_x = receipt_x + receipt_w - (spark_size // 2)
    spark_y = receipt_y - (spark_size // 2)
    
    # Simple 4-pointed star
    spark_color = (253, 224, 71) # Yellow-300
    points = [
        (spark_x, spark_y - spark_size), # Top
        (spark_x + spark_size//3, spark_y - spark_size//3),
        (spark_x + spark_size, spark_y), # Right
        (spark_x + spark_size//3, spark_y + spark_size//3),
        (spark_x, spark_y + spark_size), # Bottom
        (spark_x - spark_size//3, spark_y + spark_size//3),
        (spark_x - spark_size, spark_y), # Left
        (spark_x - spark_size//3, spark_y - spark_size//3),
    ]
    draw.polygon(points, fill=spark_color)

    return image

# Save as large PNG
icon = create_icon(1024)
icon.save("base_icon.png")
print("✅ Base icon generated.")
