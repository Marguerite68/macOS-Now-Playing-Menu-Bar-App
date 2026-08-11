set separatorCharacter to ASCII character 30

tell application "Spotify"
    set stateText to player state as text
    if stateText is "stopped" then return ""

    set mediaTrack to current track
    set trackID to ""
    try
        set trackID to id of mediaTrack as text
    end try

    set trackTitle to name of mediaTrack as text
    set trackArtist to ""
    set trackAlbum to ""
    try
        set trackArtist to artist of mediaTrack as text
    end try
    try
        set trackAlbum to album of mediaTrack as text
    end try

    return "spotify" & separatorCharacter & stateText & separatorCharacter & trackID & separatorCharacter & trackTitle & separatorCharacter & trackArtist & separatorCharacter & trackAlbum
end tell
