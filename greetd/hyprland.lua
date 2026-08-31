hl.on("hyprland.start", function()
    hl.exec_cmd("regreet -s /etc/greetd/regreet.css")
    hl.exec_cmd("hyprctl dispatch exit")
end)

hl.config({
    misc = {
        disable_hyprland_logo        = true,
        disable_splash_rendering     = true,
        disable_hyprland_guiutils_check = true,
    },
})
