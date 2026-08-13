on run
    tell application "Music"
        set stateText to player state as text
        if stateText is not "playing" then return "not-playing"
        set wasFrontmost to frontmost
        if (count of every browser window) > 0 then
            if (visible of browser window 1) or (collapsed of browser window 1) then return "existing"
            set visible of browser window 1 to true
            delay 0.2
            set collapsed of browser window 1 to true
            if not wasFrontmost then set frontmost to false
            return "created"
        end if

        reopen
        repeat 20 times
            if (count of every browser window) > 0 then exit repeat
            delay 0.05
        end repeat

        if (count of every browser window) is 0 then return "unavailable"
        set collapsed of browser window 1 to true
        if not wasFrontmost then set frontmost to false
        return "created"
    end tell
end run
