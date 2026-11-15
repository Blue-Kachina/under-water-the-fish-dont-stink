# Third-party notices

## abyssal-garden

Parts of the underwater look (the water fog and absorption model, caustics,
the surface seen from below, light shafts, post grading and the particle and
material techniques) are ported from, or use the maths and constants of,
**abyssal-garden**, a WebGPU demo: https://github.com/Noniv/abyssal-garden
(live at https://noniv.github.io/abyssal-garden/). See `planning_abyssal_look.md`
for what is taken from where.

Every file that ports their maths or constants line by line carries this header
(`//` in shaders, `#` in scripts):

    // Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md

Their licence, as published in the repository's LICENSE file:

```
MIT License

Copyright (c) 2026 Maksymilian Dendura

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Only techniques, maths and constants are used. No assets are copied (the
original has none: everything in it is procedural).
