on run
    tell application "Music"
        if (count of every browser window) is 0 then return "absent"
        if collapsed of browser window 1 then
            close browser window 1
            return "closed"
        end if
        return "restored-by-user"
    end tell
end run
