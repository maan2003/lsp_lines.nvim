- When diagnostics have background colour, space to their left is highlighted.
  This issue is introduced by this patch, and likely due to the original author
  using a theme where this is not visible.
- The last virtual_text has an invalid id. This needs to be fixed.
- For entries where column 0 is the issue, the lines don't make sense. This is
  evident for diagnostics for (col=0, row=0), which are usually meant to refer
  to the entire file.
