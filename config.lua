application = {
    content = {
        width = 720,
        height = 1280,
        scale = "letterbox",
        fps = 60,
        
        xAlign = "center",
        yAlign = "center",

        imageSuffix = {
            ["@2x"] = 2,
            ["@4x"] = 4,
        },
    },
    -- Use adaptive FPS for better battery life when possible
    -- (Requires specific plugins or implementation)
}
