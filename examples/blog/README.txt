Information
Example Blog

Blog posts are stored in content/posts/, categorized in subfolders by year and
month. It doesn't matter how/if they're categorized, but this format is pretty
common for blogs. All blog post pages specify that they should use the
"blogPost" layout.

The homepage, content/index.html, loops through all pages under the
content/posts/ folder and shows a truncated version of them. Both this index
file and the "blogPost" layout include the "_blogPost" layout which generates
the actual HTML for the given blog post.

We have given the "partial" layouts for this site a filename that starts with
an underscore. It's a good idea to separate layouts that pages can use, and
layouts used by other layouts. The "_header" and "_footer" layouts are both
included by both the "blogPost" layout and the default "page" layout.

The "_header" layout does a similar thing as the homepage - it loops through
all posts and creates a small menu with links to each one.
