#!/usr/bin/env python3
"""Assembles the README's animations from the pieces ReadmeArtTests renders.

    README_ART_DIR=/tmp/stash-art swift test --filter ReadmeArtTests
    Scripts/make_readme_art.py /tmp/stash-art

Every piece — a row, the list's top, the preview pane, a keycap, the toast — is a PNG drawn by
the journal's own SwiftUI views, so the animations look exactly like the app. This script only
places them on a desktop, wraps them in the journal's glass and moves them with CSS. Each
animation is written twice, for the light and the dark look, and the README picks one with
<picture>.
"""
import base64
import os
import struct
import sys

ART = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', 'docs', 'assets')

# ThemePalette, for the parts drawn here rather than rendered: the desktop, the window, the panes.
PALETTE = {
    'light': dict(side='rgba(255,255,255,.82)', detail='rgba(255,255,255,.38)', border='rgba(0,0,0,.10)',
                  sep='rgba(0,0,0,.08)', win='#ffffff', ink1='rgba(0,0,0,.86)', ink2='rgba(0,0,0,.58)',
                  ink3='rgba(0,0,0,.38)', mbar='rgba(255,255,255,.70)', flash='rgba(244,106,37,.15)',
                  wall=('#8fb6e8', '#c9a7d9', '#f2c6a0'), blobCool='.40'),
    'dark': dict(side='rgba(28,28,30,.84)', detail='rgba(18,18,20,.42)', border='rgba(255,255,255,.11)',
                 sep='rgba(255,255,255,.08)', win='#252526', ink1='rgba(255,255,255,.90)', ink2='rgba(255,255,255,.58)',
                 ink3='rgba(255,255,255,.38)', mbar='rgba(28,28,30,.85)', flash='rgba(244,106,37,.24)',
                 wall=('#1d2a44', '#3a2346', '#4a2f25'), blobCool='.16'),
}
FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif'
CURSOR = 'M0,0 L0,19 L5,14.6 L8.6,21.8 L12,20.2 L8.4,13.1 L14.6,12.6 Z'

ROW = 58
SECTION = 26


SCALE = 3   # the pieces are rendered at 3×, see ReadmeArtTests


def png(name):
    """The PNG as a data URI with its size in points."""
    with open(os.path.join(ART, name + '.png'), 'rb') as f:
        data = f.read()
    w, h = struct.unpack('>II', data[16:24])
    return 'data:image/png;base64,' + base64.b64encode(data).decode(), w / SCALE, h / SCALE


def image(name, x, y, ident='', size=None):
    """The piece at its rendered size, or scaled to `size` (width, height) in points."""
    uri, w, h = png(name)
    if size:
        w, h = size
    i = f' id="{ident}"' if ident else ''
    return f'<image{i} href="{uri}" x="{x}" y="{y}" width="{w}" height="{h}"/>\n'


def height(name):
    return png(name)[2]


def keycap(name, theme, x, y, ident):
    """A tour keycap at (x, y) — the PNG carries 20 pt of padding for its shadow — with its
    pressed twin on top, hidden until the press."""
    return (image(f'{name}-{theme}', x - 20, y - 20, f'{ident}Up')
            + image(f'{name}-pressed-{theme}', x - 20, y - 20, f'{ident}Down'))


def wave(x, y):
    """The tour's click ripple, white and a little bolder: a disc that swells from the click."""
    return f'<circle id="ripple" cx="{x}" cy="{y}" r="14" fill="#fff" opacity="0" filter="url(#waveShadow)"/>\n'


def cursor(ident):
    return (f'<g id="{ident}"><path d="{CURSOR}" fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></g>\n')


def defs(p, w, h, blob):
    """Gradients, the blur, and the desktop drawn once so the glass can show it blurred."""
    c0, c1, c2 = p['wall']
    bx, by = blob
    return f'''<defs>
  <linearGradient id="wall" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{c0}"/><stop offset=".45" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/>
  </linearGradient>
  <radialGradient id="blobWarm"><stop offset="0" stop-color="#f46a25" stop-opacity=".55"/><stop offset="1" stop-color="#f46a25" stop-opacity="0"/></radialGradient>
  <radialGradient id="blobCool"><stop offset="0" stop-color="#fff" stop-opacity="{p['blobCool']}"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
  <filter id="frost" x="-15%" y="-15%" width="130%" height="130%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="14"/></filter>
  <filter id="panelShadow" x="-25%" y="-25%" width="150%" height="160%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="14"/><feOffset dy="8" result="o"/>
    <feFlood flood-color="#000" flood-opacity=".30"/><feComposite in2="o" operator="in"/>
  </filter>
  <filter id="waveShadow" x="-60%" y="-60%" width="220%" height="220%"><feDropShadow dx="0" dy="2" stdDeviation="4" flood-color="#000" flood-opacity=".35"/></filter>
  <filter id="winShadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#000" flood-opacity=".26"/></filter>
  <g id="deskBg">
    <rect x="0" y="0" width="{w}" height="{h}" rx="18" fill="url(#wall)"/>
    <ellipse cx="{bx}" cy="{by}" rx="240" ry="200" fill="url(#blobWarm)"/>
    <ellipse cx="150" cy="70" rx="220" ry="160" fill="url(#blobCool)"/>
  </g>
</defs>
'''


def panel(p, x, y, w, h, side_w, inner, ident='panel'):
    """The journal's glass: its shadow on a layer of its own (a filter over the pieces would have
    them rasterised soft), the desktop blurred, the two panes' tints, a hairline, and the pieces."""
    r = 24
    return f'''<g id="{ident}">
  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" filter="url(#panelShadow)"/>
  <clipPath id="{ident}Clip"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}"/></clipPath>
  <g clip-path="url(#{ident}Clip)">
    <g filter="url(#frost)"><use href="#deskBg"/></g>
    <rect x="{x}" y="{y}" width="{side_w}" height="{h}" fill="{p['side']}"/>
    {'' if side_w == w else f'<rect x="{x + side_w}" y="{y}" width="{w - side_w}" height="{h}" fill="{p["detail"]}"/><rect x="{x + side_w - 1}" y="{y}" width="1" height="{h}" fill="{p["sep"]}"/>'}
{inner}  </g>
  <rect x="{x + .5}" y="{y + .5}" width="{w - 1}" height="{h - 1}" rx="{r - .5}" fill="none" stroke="{p['border']}" stroke-width="1"/>
</g>
'''


def svg(w, h, label, body, css):
    label = label.replace('"', '&quot;')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="{label}">
<title>{label}</title>
<style>
svg{{font-family:{FONT}}}
{css}
@media (prefers-reduced-motion: reduce){{ * {{animation:none !important}} }}
</style>
{body}</svg>
'''


# ── the hero ───────────────────────────────────────────────────────────────────

def hero(theme):
    """A narrow messenger. "Did you ship 1.10?" — "Yes" — then a line is typed, ⌥V opens the
    journal above the caret, the pointer double-clicks the link and the message goes out; a second
    line, ⌥V again, the arrow key picks the screenshot, Return pastes it and sends it. 15 s."""
    p = PALETTE[theme]
    t = '-' + theme
    W, H = 1000, 640
    WX, WW = 125, 340                       # the chat window; with the journal it sits centred
    FX, FW = WX + 16, WW - 32               # its message field
    PX, PY = WX + 110, 44                   # the journal, above the caret: there is no room below
    ys = {}
    y = PY
    ys['top'] = y; y += height('list-top-5' + t)
    ys['pinned'] = y; y += SECTION
    ys['email'] = y; y += ROW
    ys['today'] = y; y += SECTION
    ys['photo'] = y; y += ROW
    ys['url'] = y; y += ROW
    ys['release'] = y; y += ROW
    ys['invoice'] = y
    tip = (PX + 150, ys['url'] + 22)        # where the pointer double-clicks the link's row
    blue, blue_ink = '#2b7cf6', '#fff'
    grey, grey_ink = ('#e9e9eb', 'rgba(0,0,0,.86)') if theme == 'light' else ('#3a3a3c', 'rgba(255,255,255,.9)')
    right = WX + WW - 16

    def bubble(text, width, y, mine, ident=''):
        w = width + 24
        x = right - w if mine else FX
        i = f' id="{ident}"' if ident else ''
        return (f'  <g{i}><rect x="{x}" y="{y}" width="{w}" height="30" rx="15" fill="{blue if mine else grey}"/>'
                f'<text x="{x + 12}" y="{y + 19}" font-size="13" fill="{blue_ink if mine else grey_ink}">{text}</text></g>\n')

    inner = (image('list-top-5' + t, PX, ys['top'])
             + image('section-pinned' + t, PX, ys['pinned'])
             + image('row-email' + t, PX, ys['email'])
             + image('section-today' + t, PX, ys['today'])
             + image('row-photo' + t, PX, ys['photo'])
             + image('row-photo-selected' + t, PX, ys['photo'], 'photoSel')
             + image('row-url' + t, PX, ys['url'])
             + image('row-url-selected' + t, PX, ys['url'], 'urlSel')
             + image('row-release' + t, PX, ys['release'])
             + image('row-invoice' + t, PX, ys['invoice'])
             + image('detail-photo' + t, PX + 290, PY, 'detPhoto')
             + image('detail-url' + t, PX + 290, PY, 'detUrl'))

    body = defs(p, W, H, (880, 600)) + '<use href="#deskBg"/>\n'
    body += f"""<path d="M18,0 H982 A18,18 0 0 1 1000,18 V30 H0 V18 A18,18 0 0 1 18,0 Z" fill="{p['mbar']}"/>
<text x="24" y="19" font-size="11" font-weight="600" fill="{p['ink1']}">Messenger</text>
<text x="94" y="19" font-size="11" fill="{p['ink2']}">File</text>
<text x="126" y="19" font-size="11" fill="{p['ink2']}">Edit</text>
<text x="162" y="19" font-size="11" fill="{p['ink2']}">View</text>
<text x="972" y="19" font-size="11" fill="{p['ink2']}" text-anchor="end">Mon 14:02</text>
<g filter="url(#winShadow)"><rect x="{WX}" y="58" width="{WW}" height="482" rx="10" fill="{p['win']}"/></g>
<rect x="{WX + .5}" y="58.5" width="{WW - 1}" height="481" rx="9.5" fill="none" stroke="{p['border']}"/>
<circle cx="{WX + 18}" cy="70" r="6" fill="#ff5f57"/><circle cx="{WX + 38}" cy="70" r="6" fill="#febc2e"/><circle cx="{WX + 58}" cy="70" r="6" fill="#28c840"/>
<text x="{WX + WW / 2}" y="74" font-size="11" font-weight="600" fill="{p['ink2']}" text-anchor="middle">Messenger</text>
<rect x="{WX}" y="82" width="{WW}" height="1" fill="{p['sep']}"/>
<clipPath id="winClip"><rect x="{WX}" y="58" width="{WW}" height="482" rx="10"/></clipPath>
<g clip-path="url(#winClip)">
"""
    body += bubble('Did you ship 1.10?', 108, 98, False)
    body += bubble('Yes', 21.4, 138, True)
    body += bubble('Here it is: github.com/KiraMurano/stash', 239.1, 178, True, 'sent1')
    body += '  <g id="sent2">\n' + bubble('And this is how it looks now:', 170.7, 218, True)
    body += '  ' + image('photo-pasted' + t, right - 220, 258, size=(220, 137.5)) + '  </g>\n'
    body += f"""  <rect x="{FX}" y="490" width="{FW}" height="34" rx="17" fill="{p['win']}" stroke="{p['border']}"/>
  <g id="msg1">
    <text x="{FX + 16}" y="512" font-size="14" fill="{p['ink1']}">Here it is: github.com/KiraMurano/stash</text>
    <g id="reveal1"><rect x="{FX + 17}" y="492" width="{FW}" height="30" fill="{p['win']}"/><rect class="caret" x="{FX + 14.5}" y="498" width="1.5" height="18" fill="{p['ink1']}"/></g>
  </g>
  <g id="msg2">
    <text x="{FX + 16}" y="512" font-size="14" fill="{p['ink1']}">And this is how it looks now:</text>
"""
    body += '    ' + image('photo-pasted' + t, FX + 16 + 181.9 + 8, 494, 'attach', size=(41.6, 26))
    body += f"""    <g id="reveal2"><rect x="{FX + 17}" y="492" width="{FW}" height="30" fill="{p['win']}"/><rect class="caret" x="{FX + 14.5}" y="498" width="1.5" height="18" fill="{p['ink1']}"/></g>
  </g>
</g>
"""
    kx, ky = WX + WW / 2 - 64, 560          # under the window, side by side and centred on it, as in the tour
    body += '<g id="keys">\n' + keycap('key-option', theme, kx, ky, 'kOpt') + keycap('key-v', theme, kx + 68, ky, 'kV') + '</g>\n'
    body += '<g id="kUp">\n' + keycap('key-up', theme, kx + 34, ky, 'kUp') + '</g>\n'
    body += '<g id="kRet">\n' + keycap('key-return', theme, kx + 34, ky, 'kRet') + '</g>\n'
    body += panel(p, PX, PY, 640, 440, 290, inner)
    body += wave(*tip) + cursor('cur')

    css = f"""
#panel{{transform-box:fill-box;transform-origin:8% 95%;animation:panelIn 15s infinite}}
@keyframes panelIn{{
  0%,11.3%{{opacity:0;transform:translateY(-12px) scale(.94);animation-timing-function:cubic-bezier(.2,.9,.25,1)}}
  13.7%,22%{{opacity:1;transform:none}}
  24%,48%{{opacity:0;transform:translateY(-8px) scale(.97);animation-timing-function:cubic-bezier(.2,.9,.25,1)}}
  50.3%,62%{{opacity:1;transform:none}}
  64%,100%{{opacity:0;transform:translateY(-8px) scale(.97)}}
}}
/* Each line is one run of text under a cover the colour of the field; the cover's left edge carries
   the caret. Pasting jumps it past the link; sending puts it back to the start. */
#msg1{{animation:msg1 15s infinite}} #msg2{{animation:msg2 15s infinite}}
@keyframes msg1{{0%,27.2%{{opacity:1}}27.3%,100%{{opacity:0}}}}
@keyframes msg2{{0%,27.2%{{opacity:0}}27.3%,100%{{opacity:1}}}}
#reveal1{{animation:reveal1 15s infinite}}
@keyframes reveal1{{
  0%,2%{{transform:translateX(0)}} 2.1%,4%{{transform:translateX(30.9px)}} 4.1%,6%{{transform:translateX(42.9px)}}
  6.1%,21.9%{{transform:translateX(61.2px)}} 22%,27.2%{{transform:translateX(254.9px)}} 27.3%,100%{{transform:translateX(0)}}
}}
#reveal2{{animation:reveal2 15s infinite}}
@keyframes reveal2{{
  0%,30.6%{{transform:translateX(0)}} 30.7%,32.6%{{transform:translateX(25.8px)}} 32.7%,34.6%{{transform:translateX(53px)}}
  34.7%,36.6%{{transform:translateX(67.3px)}} 36.7%,38.6%{{transform:translateX(97.7px)}} 38.7%,40.6%{{transform:translateX(109.8px)}}
  40.7%,42.6%{{transform:translateX(147.5px)}} 42.7%,67.2%{{transform:translateX(181.9px)}} 67.3%,100%{{transform:translateX(0)}}
}}
.caret{{animation:blink 1s steps(1,end) infinite}}
@keyframes blink{{0%,60%{{opacity:1}}60.01%,100%{{opacity:0}}}}
#attach{{animation:attach 15s infinite}}
@keyframes attach{{0%,62.6%{{opacity:0}}62.7%,67.2%{{opacity:1}}67.3%,100%{{opacity:0}}}}
#sent1{{animation:sent1 15s infinite}} #sent2{{animation:sent2 15s infinite}}
@keyframes sent1{{0%,27.2%{{opacity:0}}27.3%,90%{{opacity:1}}94%,100%{{opacity:0}}}}
@keyframes sent2{{0%,67.2%{{opacity:0}}67.3%,90%{{opacity:1}}94%,100%{{opacity:0}}}}
#keys,#kUp,#kRet,#cur,#ripple{{transform-box:fill-box}} #ripple{{transform-origin:50% 50%}}
/* ⌥V twice */
#keys{{animation:keysIn 15s infinite}}
@keyframes keysIn{{
  0%,7%{{opacity:0;transform:translateY(8px)}} 8%,13%{{opacity:1;transform:none}} 14%,43.7%{{opacity:0;transform:translateY(-6px)}}
  44.7%,49.7%{{opacity:1;transform:none}} 50.7%,100%{{opacity:0;transform:translateY(-6px)}}
}}
#kOptDown{{animation:optPress 15s infinite}} #kVDown{{animation:vPress 15s infinite}}
@keyframes optPress{{0%,8.9%{{opacity:0}}9%,10%{{opacity:1}}10.1%,45.6%{{opacity:0}}45.7%,46.7%{{opacity:1}}46.8%,100%{{opacity:0}}}}
@keyframes vPress{{0%,9.9%{{opacity:0}}10%,11%{{opacity:1}}11.1%,46.6%{{opacity:0}}46.7%,47.7%{{opacity:1}}47.8%,100%{{opacity:0}}}}
/* the pointer comes up from the field and double-clicks the link's row */
#cur{{animation:curMove 15s infinite}}
@keyframes curMove{{
  0%,13.9%{{opacity:0;transform:translate({WX + 190}px,500px)}}
  14.7%{{opacity:1;transform:translate({WX + 190}px,500px);animation-timing-function:cubic-bezier(.35,0,.2,1)}}
  20%,22.5%{{opacity:1;transform:translate({tip[0]}px,{tip[1]}px)}}
  24%,100%{{opacity:0;transform:translate({tip[0]}px,{tip[1]}px)}}
}}
#ripple{{animation:rip 15s infinite}}
@keyframes rip{{0%,20.6%{{opacity:0;transform:scale(.3)}}20.7%{{opacity:.85;transform:scale(.3)}}21.6%{{opacity:0;transform:scale(2.6)}}21.7%{{opacity:.85;transform:scale(.3)}}24%,100%{{opacity:0;transform:scale(2.6)}}}}
/* the up arrow takes the selection to the screenshot */
#kUp{{animation:upIn 15s infinite}}
@keyframes upIn{{0%,52.6%{{opacity:0;transform:translateY(8px)}}53.3%,58.3%{{opacity:1;transform:none}}59.3%,100%{{opacity:0;transform:translateY(-6px)}}}}
#kUpDown{{animation:upPress 15s infinite}}
@keyframes upPress{{0%,55.2%{{opacity:0}}55.3%,56.3%{{opacity:1}}56.4%,100%{{opacity:0}}}}
/* Return pastes the screenshot; the messages are sent without showing a key */
#kRet{{animation:retIn 15s infinite}}
@keyframes retIn{{0%,58.6%{{opacity:0;transform:translateY(8px)}}59.3%,63.5%{{opacity:1;transform:none}}64.5%,100%{{opacity:0;transform:translateY(-6px)}}}}
#kRetDown{{animation:retPress 15s infinite}}
@keyframes retPress{{0%,60.9%{{opacity:0}}61%,62%{{opacity:1}}62.1%,100%{{opacity:0}}}}
/* the app switches the selection outright, so the rows do too */
#photoSel,#detPhoto{{animation:photoOn 15s infinite}} #urlSel,#detUrl{{animation:urlOn 15s infinite}}
@keyframes photoOn{{0%,20.6%{{opacity:1}}20.7%,55.2%{{opacity:0}}55.3%,100%{{opacity:1}}}}
@keyframes urlOn{{0%,20.6%{{opacity:0}}20.7%,55.2%{{opacity:1}}55.3%,100%{{opacity:0}}}}
/* the page starts every loop at zero, so it begins where the journal flies in */
* {{ animation-delay: -1.5s !important }}
"""
    return svg(W, H, 'In a messenger, after "Did you ship 1.10?" and "Yes", a line is typed; ⌥V opens the Stash journal above the caret; the pointer double-clicks the link and the message is sent; a second line, ⌥V again, the arrow key picks the screenshot, Return pastes and sends it.', body, css)


# ── the feature strips: the list pane on a desktop ────────────────────────────

CW, CH = 470, 366
CX, CY, CWID = 150, 20, 290
PANE_H = 326


def strip_rows(theme, rows, top='list-top-3'):
    """The list's top, then `rows` as (piece, ident) at the journal's row pitch. A piece named
    'today'/'pinned' is a section header."""
    t = '-' + theme
    y = CY + height(top + t)
    out = image(top + t, CX, CY)
    for piece, ident in rows:
        if piece in ('today', 'pinned'):
            out += image('section-' + piece + t, CX, y, ident)
            y += SECTION
        else:
            out += image(piece + t, CX, y, ident)
            y += ROW
    return out


def strip(theme, label, inner, art, css):
    p = PALETTE[theme]
    # the keys, the pointer and its click wave are drawn after the journal so they stay on top of it
    body = defs(p, CW, CH, (CW - 90, CH - 20)) + '<use href="#deskBg"/>\n' + panel(p, CX, CY, CWID, PANE_H, CWID, inner, 'card') + art
    return svg(CW, CH, label, body, css)


def toast(theme):
    uri, w, h = png('toast-pasted-' + theme)
    # centred at the pane's bottom, like the app's ToastOverlay
    return f'<image id="toast" href="{uri}" x="{CX + CWID / 2 - w / 2}" y="{CY + PANE_H - 60 - h / 2}" width="{w}" height="{h}"/>\n'


def open_strip(theme):
    rows = [('today', ''), ('row-photo-selected', ''), ('row-url', ''), ('row-release', '')]
    art = '<g id="keys">\n' + keycap('key-option', theme, 12, 153, 'kOpt') + keycap('key-v', theme, 80, 153, 'kV') + '</g>\n'
    css = '''
#keys{transform-box:fill-box;animation:kIn 5s infinite}
@keyframes kIn{0%{opacity:0;transform:translateY(6px)}3%,20%{opacity:1;transform:none}26%,100%{opacity:0;transform:translateY(-6px)}}
#kOptDown{animation:optPress 5s infinite} #kVDown{animation:vPress 5s infinite}
@keyframes optPress{0%,7%{opacity:0}7.1%,10%{opacity:1}10.1%,100%{opacity:0}}
@keyframes vPress{0%,10%{opacity:0}10.1%,13%{opacity:1}13.1%,100%{opacity:0}}
#card{transform-box:fill-box;transform-origin:6% 8%;animation:cardIn 5s infinite}
@keyframes cardIn{
  0%,11%{opacity:0;transform:translateY(12px) scale(.94);animation-timing-function:cubic-bezier(.2,.9,.25,1)}
  18%,95%{opacity:1;transform:none}
  99.5%,100%{opacity:0;transform:translateY(8px) scale(.97)}
}
* { animation-delay: -1.2s !important }
'''
    return strip(theme, 'Two keycaps, option and V, are pressed and the Stash journal springs open.', strip_rows(theme, rows), art, css)


def paste_strip(theme):
    t = '-' + theme
    y = CY + height('list-top-3' + t)
    inner = image('list-top-3' + t, CX, CY) + image('section-today' + t, CX, y)
    y += SECTION
    inner += image('row-photo' + t, CX, y) + image('row-photo-selected' + t, CX, y, 'photoSel')
    y += ROW
    inner += image('row-url' + t, CX, y) + image('row-url-selected' + t, CX, y, 'urlSel')
    tip = (CX + 150, y + 26)
    y += ROW
    inner += image('row-release' + t, CX, y)
    inner += toast(theme)
    art = wave(tip[0], tip[1]) + cursor('cur')
    css = f'''
#cur,#ripple,#toast{{transform-box:fill-box}} #ripple{{transform-origin:50% 50%}}
#cur{{animation:curMove 5s infinite}}
@keyframes curMove{{
  0%,4%{{opacity:0;transform:translate(36px,300px)}}
  8%{{opacity:1;transform:translate(36px,300px);animation-timing-function:cubic-bezier(.35,0,.2,1)}}
  22%,70%{{opacity:1;transform:translate({tip[0]}px,{tip[1]}px)}}
  78%,100%{{opacity:0;transform:translate({tip[0]}px,{tip[1]}px)}}
}}
@keyframes rip{{0%,23%{{opacity:0;transform:scale(.3)}}24%{{opacity:.85;transform:scale(.3)}}29%{{opacity:0;transform:scale(2.6)}}29.5%{{opacity:.85;transform:scale(.3)}}34.5%,100%{{opacity:0;transform:scale(2.6)}}}}
#ripple{{animation:rip 5s infinite}}
#photoSel{{animation:wasPhoto 5s infinite}} #urlSel{{animation:isUrl 5s infinite}}
@keyframes wasPhoto{{0%,28.9%{{opacity:1}}29%,100%{{opacity:0}}}}
@keyframes isUrl{{0%,28.9%{{opacity:0}}29%,100%{{opacity:1}}}}
#toast{{animation:toastIn 5s infinite}}
@keyframes toastIn{{0%,31%{{opacity:0;transform:translateY(6px)}}35%,68%{{opacity:1;transform:none}}76%,100%{{opacity:0;transform:translateY(-4px)}}}}
* {{ animation-delay: -0.4s !important }}
'''
    return strip(theme, 'A pointer double-clicks a clip in the list and a Pasted badge appears.', inner, art, css)


def keys_strip(theme):
    t = '-' + theme
    y = CY + height('list-top-3' + t)
    inner = image('list-top-3' + t, CX, CY) + image('section-today' + t, CX, y)
    y += SECTION
    inner += image('row-photo' + t, CX, y) + image('row-photo-selected' + t, CX, y, 'sel1'); y += ROW
    inner += image('row-url' + t, CX, y) + image('row-url-selected' + t, CX, y, 'sel2'); y += ROW
    inner += image('row-release' + t, CX, y) + image('row-release-selected' + t, CX, y, 'sel3')
    inner += toast(theme)
    art = '<g id="keys">\n' + keycap('key-down', theme, 12, 153, 'kDown') + keycap('key-return', theme, 80, 153, 'kRet') + '</g>\n'
    css = '''
#keys,#toast{transform-box:fill-box}
#keys{animation:kIn 6s infinite}
@keyframes kIn{0%,10%{opacity:0;transform:translateY(6px)}13%,74%{opacity:1;transform:none}80%,100%{opacity:0;transform:translateY(-6px)}}
#kDownDown{animation:downPress 6s infinite}
@keyframes downPress{0%,19.9%{opacity:0}20%,22.5%{opacity:1}22.6%,31.9%{opacity:0}32%,34.5%{opacity:1}34.6%,100%{opacity:0}}
#kRetDown{animation:retPress 6s infinite}
@keyframes retPress{0%,45.9%{opacity:0}46%,48.5%{opacity:1}48.6%,100%{opacity:0}}
#sel1{animation:s1 6s infinite} #sel2{animation:s2 6s infinite} #sel3{animation:s3 6s infinite}
@keyframes s1{0%,20%{opacity:1}20.1%,100%{opacity:0}}
@keyframes s2{0%,20%{opacity:0}20.1%,32%{opacity:1}32.1%,100%{opacity:0}}
@keyframes s3{0%,32%{opacity:0}32.1%,100%{opacity:1}}
#toast{animation:toastIn 6s infinite}
@keyframes toastIn{0%,48%{opacity:0;transform:translateY(6px)}52%,76%{opacity:1;transform:none}84%,100%{opacity:0;transform:translateY(-4px)}}
'''
    return strip(theme, 'The down arrow key walks the selection through the list and Return pastes the clip.', inner, art, css)


def pin_strip(theme):
    t = '-' + theme
    y0 = CY + height('list-top-3' + t)
    y_photo, y_url, y_release = y0 + SECTION, y0 + SECTION + ROW, y0 + SECTION + 2 * ROW
    inner = image('list-top-3' + t, CX, CY)
    inner += image('section-pinned' + t, CX, y0, 'lblPinned')
    inner += image('section-today' + t, CX, y0, 'lblToday')
    inner += image('row-photo' + t, CX, y_photo, 'rowPhoto')
    inner += image('row-release' + t, CX, y_release, 'rowRelease')
    inner += ('<g id="rowUrl">\n' + image('row-url' + t, CX, y_url, 'urlPlain') + image('row-url-hovered' + t, CX, y_url, 'urlHover')
              + image('row-url-pinned' + t, CX, y_url, 'urlPinned') + '</g>\n')
    # the pin button of a hovered row: 8 pt in from the row's end, 26 pt wide, 4 pt before the trash
    pin = (CX + CWID - 10 - 8 - 26 - 4 - 13, y_url + 29)
    art = wave(pin[0], pin[1]) + cursor('cur')
    css = f'''
#rowPhoto,#rowRelease,#rowUrl,#lblToday,#cur,#ripple{{transform-box:fill-box}} #ripple{{transform-origin:50% 50%}}
#cur{{animation:curMove 5.5s infinite}}
@keyframes curMove{{
  0%,4%{{opacity:0;transform:translate(36px,300px)}}
  8%{{opacity:1;transform:translate(36px,300px);animation-timing-function:cubic-bezier(.35,0,.2,1)}}
  22%,30%{{opacity:1;transform:translate({pin[0] - 3}px,{pin[1] - 2}px)}}
  37%,100%{{opacity:0;transform:translate({pin[0] - 3}px,{pin[1] - 2}px)}}
}}
@keyframes rip{{0%,24%{{opacity:0;transform:scale(.3)}}25%{{opacity:.85;transform:scale(.3)}}32%,100%{{opacity:0;transform:scale(2.6)}}}}
#ripple{{animation:rip 5.5s infinite}}
/* the row lights up when the pointer reaches it, and turns pinned on the click */
#urlHover{{animation:hover 5.5s infinite}} #urlPinned{{animation:pinned 5.5s infinite}}
@keyframes hover{{0%,15%{{opacity:0}}15.1%,25.9%{{opacity:1}}26%,100%{{opacity:0}}}}
@keyframes pinned{{0%,25.9%{{opacity:0}}26%,90%{{opacity:1}}92%,100%{{opacity:0}}}}
#rowUrl{{animation:flyUp 5.5s infinite}}
@keyframes flyUp{{0%,28%{{transform:translateY(0);animation-timing-function:cubic-bezier(.2,.9,.25,1)}}36%,86%{{transform:translateY(-{ROW}px);animation-timing-function:cubic-bezier(.4,0,.25,1)}}94%,100%{{transform:translateY(0)}}}}
#rowPhoto,#lblToday{{animation:down84 5.5s infinite}} #rowRelease{{animation:down26 5.5s infinite}}
@keyframes down84{{0%,28%{{transform:translateY(0);animation-timing-function:cubic-bezier(.2,.9,.25,1)}}36%,86%{{transform:translateY({ROW + SECTION}px);animation-timing-function:cubic-bezier(.4,0,.25,1)}}94%,100%{{transform:translateY(0)}}}}
@keyframes down26{{0%,28%{{transform:translateY(0);animation-timing-function:cubic-bezier(.2,.9,.25,1)}}36%,86%{{transform:translateY({SECTION}px);animation-timing-function:cubic-bezier(.4,0,.25,1)}}94%,100%{{transform:translateY(0)}}}}
#lblPinned{{animation:swapIn 5.5s infinite}}
@keyframes swapIn{{0%,29%{{opacity:0}}34%,86%{{opacity:1}}92%,100%{{opacity:0}}}}
'''
    return strip(theme, 'A clip pin button is clicked and the clip moves to the top of the list, under Pinned.', inner, art, css)


def main():
    os.makedirs(OUT, exist_ok=True)
    for theme in ('light', 'dark'):
        for name, make in (('hero', hero), ('open', open_strip), ('paste', paste_strip), ('keys', keys_strip), ('pin', pin_strip)):
            path = os.path.join(OUT, f'{name}-{theme}.svg')
            with open(path, 'w') as f:
                f.write(make(theme))
            print(f'{path}  {os.path.getsize(path) // 1024} KB')
        # the lockup at the top of the README is a PNG on its own
        with open(os.path.join(ART, f'wordmark-{theme}.png'), 'rb') as src, open(os.path.join(OUT, f'wordmark-{theme}.png'), 'wb') as dst:
            dst.write(src.read())


if __name__ == '__main__':
    main()
