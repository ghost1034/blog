import os
import re
import shutil

#  (1) Adjust these three paths to YOUR environment
posts_dir         = "/Users/ianstewart/ianblog/content/posts/"
attachments_dir   = "/Users/ianstewart/Chest/attachments/"
static_images_dir = "/Users/ianstewart/ianblog/static/images/"

# (A) Make sure posts_dir and static_images_dir both end with a slash
if not posts_dir.endswith("/"):
    posts_dir += "/"
if not static_images_dir.endswith("/"):
    static_images_dir += "/"

# (2) Loop over every Markdown file in content/posts/
for filename in os.listdir(posts_dir):
    if not filename.endswith(".md"):
        continue

    filepath = os.path.join(posts_dir, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # (3) Pattern to match Obsidian image embeds:  ![[my file.png]]
    #
    #      Breakdown of the regex:
    #        -  !            : a literal exclamation mark
    #        -  \[\[         : two literal opening brackets
    #        -  ([^\]]+\.png): capture group1 =  "one or more non-] characters ending in .png"
    #        -  \]\]         : two literal closing brackets
    #
    # Example it matches:   ![[Diagram 1.png]]     or    ![[foo bar.png]]
    #
    # We'll replace each match with Markdown: 
    #    ![Diagram 1](/blog/images/Diagram%201.png)
    # 
    image_pattern = re.compile(r'!\[\[([^\]]+\.png)\]\]')

    # (4) Define a replacement function for re.sub
    def replace_embed_with_markdown(match):
        img_filename = match.group(1)  # e.g. "Diagram 1.png"
        # (a) Copy the file from attachments_dir to static_images_dir
        src = os.path.join(attachments_dir, img_filename)
        if os.path.exists(src):
            shutil.copy(src, static_images_dir)
        else:
            print(f"Warning: {src} not found (skipping copy).")

        # (b) Build the Markdown-style image link:
        #     We'll use the file name (minus extension) as alt text
        alt_text = os.path.splitext(img_filename)[0]   # e.g. "Diagram 1"
        # Replace spaces with %20 in the URL part
        url_path = img_filename.replace(" ", "%20")    # e.g. "Diagram%201.png"
        # Your site probably serves images at /blog/images/... if your baseURL is  "/blog/"
        return f"![{alt_text}](/blog/images/{url_path})"

    # (5) Perform the substitution on the entire file content
    new_content = image_pattern.sub(replace_embed_with_markdown, content)

    # (6) Write the updated content back to the markdown file
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(new_content)

print("Markdown files processed and images copied successfully.")
