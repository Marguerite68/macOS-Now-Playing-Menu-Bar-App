set separatorCharacter to character id 30

tell application "Spotify"
    set stateText to player state as text
    if stateText is "stopped" then return ""

    set mediaTrack to current track
    set trackIdentifier to ""
    try
        set trackIdentifier to id of mediaTrack as text
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

    set coverLocation to ""
    try
        set coverLocation to artwork url of mediaTrack as text
    end try

    return "spotify" & separatorCharacter & stateText & separatorCharacter & trackIdentifier & separatorCharacter & trackTitle & separatorCharacter & trackArtist & separatorCharacter & trackAlbum & separatorCharacter & coverLocation
end tell
