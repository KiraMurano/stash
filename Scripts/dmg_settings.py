# dmgbuild settings for the Stash installer window: white background with an
# orange arc from Stash to Applications (Scripts/make_dmg_background.swift).
# Window content is 540x380 pt; icon centres match the arc's ends.
import os

root = defines["root"]

format = "UDZO"
filesystem = "HFS+"
files = [os.path.join(root, ".build/Stash.app")]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["Stash.app"]

background = os.path.join(root, "Resources/DMGBackground.png")
window_rect = ((200, 120), (540, 380))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    "Stash.app": (140, 170),
    "Applications": (400, 170),
}
