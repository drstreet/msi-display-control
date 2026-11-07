/// Every OSD setting the app knows, in menu order.
///
/// Power (00100) and factory reset (00840) are left out on purpose. Registers outside
/// this list are never read or written: some of them hang or damage the firmware.
public enum Catalog {
    public static let features: [Feature] = gaming + professional + image + input + pictureInPicture
        + naviKey + lighting + system

    public static func feature(_ code: String) -> Feature? { features.first { $0.code == code } }

    public static func features(in category: Category) -> [Feature] {
        features.filter { $0.category == category }
    }

    public enum Code {
        public static let macroKey = "00110"
        public static let activeMode = "00120"
        public static let serial = "00130"
        public static let model = "00140"
        public static let version = "00150"
        public static let firmware = "001<0"
        public static let refreshRate = "00170"
        public static let gameMode = "00200"
        public static let proMode = "00300"
        public static let brightness = "00400"
        public static let input = "00500"
        public static let pictureInPicture = "00600"
    }

    // MARK: - Shared option lists

    private static let offOn = Control.choice(["Off", "On"])
    private static let corners = ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]
    private static let cornersOrCustom = Control.choice(corners + ["Custom"])
    private static let fourInputs = Control.choice(["HDMI 1", "HDMI 2", "DisplayPort", "USB-C"])
    private static let threeInputs = Control.choice(["HDMI 1", "HDMI 2", "DisplayPort"])
    private static let percent = Control.range(0...100)
    private static let gameModes = ["User", "FPS", "Racing", "RTS", "RPG"]
    private static let crosshairIcons = Control.choice(["Off", "Icon 1", "Icon 2", "Icon 3", "Icon 4", "Icon 5", "Icon 6"])

    private static let colorFamily: Series = [.mag, .mpg, .mag321qr, .mag251rx, .mag274qrx, .md272qp, .mag401qr]
    private static let pipFamily: Series = [.mag321curv, .mag321cqr, .mag271cqr, .mpg27cq, .mag274qrx, .mag401qr]
    private static let creatorPIP: Series = [.ps341wu, .mpg341cqr]

    // MARK: - Gaming

    private static let gaming: [Feature] = [
        Feature(Code.gameMode, "Game Mode", .gaming,
                summary: "Picture presets tuned for a game genre. Choosing one replaces the Pro Mode.",
                [(.mag274qrfqd20, .choice(gameModes + ["Premium Color"])),
                 (Series.all.subtracting([.ps341wu, .md272qp]), .choice(gameModes))]),
        Feature("002;0", "Night Vision", .gaming,
                summary: "Brightens dark areas so enemies hiding in shadows are easier to spot. Bright areas stay the same.",
                illustration: .nightVision,
                [([.mag321curv, .mag272Family, .mag274Family, .mpg341cqr, .mpg273cqr, .mag321qr, .mag251rx, .mag274qrx, .mag401qr],
                  .choice(["Off", "Normal", "Strong", "Strongest", "A.I."]))]),
        Feature("00210", "Black Tuner", .gaming,
                summary: "Lifts or deepens the darkest shades. Higher values show more detail in dark scenes.",
                illustration: .nightVision, encoding: .mixed(100),
                [([.mag271cqr, .mag241Family, .mpg27cq], .range(0...20))]),
        Feature("00220", "Response Time", .gaming,
                summary: "Overdrive: makes pixels change colour faster, which reduces the smear behind moving objects. Fastest can add a bright halo around edges.",
                illustration: .responseTime,
                [(.all, .choice(["Normal", "Fast", "Fastest"]))]),
        Feature("00230", "MPRT", .gaming,
                summary: "Moving Picture Response Time. Flashes the backlight between frames so motion looks as sharp as a still image. The screen gets darker, and Adaptive-Sync and HDCR turn off. Needs a refresh rate above 85 Hz.",
                illustration: .mprt,
                [(.mag401qr, offOn),
                 ([.mag, .mpg341cqr, .mag251rx], .choice(["On", "Off"]))]),
        Feature("00280", "Adaptive-Sync", .gaming,
                summary: "FreeSync / G-Sync Compatible. The monitor waits for each frame from the graphics card, which removes tearing (the image splitting horizontally) when the frame rate changes.",
                illustration: .adaptiveSync,
                [([.mag321cqr, .mag272Family, .mag271cqr, .mag241Family, .mag274Family, .mpg341cqr, .mpg273cqr, .mpg27cq,
                   .mag321qr, .md272qp, .mag401qr], offOn)]),
        Feature("00290", "Zero Latency", .gaming,
                summary: "Skips internal image processing to cut input lag.",
                [([.mag321curv, .mag321cqr, .mag271cqr, .mpg341cqr, .mpg27cq], offOn)]),
        Feature("00250", "Refresh Rate Display", .gaming,
                summary: "Shows the current refresh rate (Hz) in a corner of the screen.",
                illustration: .onScreenInfo,
                [([.mag, .mpg, .mag321qr, .mag251rx, .mag274qrx, .md272qp, .mag401qr], offOn)]),
        Feature("00251", "Refresh Rate Location", .gaming,
                summary: "Corner used for the refresh rate counter.",
                [([.mag274qrx, .mag401qr], cornersOrCustom),
                 ([.mag, .mpg, .mag321qr, .mag251rx, .md272qp], .choice(corners))]),
        Feature("00260", "Alarm Clock", .gaming,
                summary: "An on-screen countdown timer, for example for respawns or breaks.",
                illustration: .onScreenInfo,
                [(.mag401qr, .choice(["Off", "15:00", "30:00", "45:00", "60:00"])),
                 ([.mag, .ps341wu, .mpg273cqr, .mpg27cq, .mag321qr, .mag274qrx, .md272qp],
                  .choice(["Off", "Timer 1", "Timer 2", "Timer 3", "Timer 4"]))]),
        Feature("00261", "Alarm Clock Timer", .gaming,
                summary: "Which of the four timers is being edited.",
                [(.mag321curv, .range(1...4))]),
        Feature("00262", "Alarm Clock Time", .gaming,
                summary: "Length of the selected timer.",
                encoding: .mixed(60),
                [([.mag321curv, .mpg273cqr, .mag321qr], .range(0...5999, format: .minutesAndSeconds))]),
        Feature("00263", "Alarm Clock Location", .gaming,
                summary: "Corner used for the timer.",
                [([.ps341wu, .mpg273cqr, .mag321qr, .mag251rx, .mag274qrx, .mag401qr], cornersOrCustom),
                 ([.mag, .mpg27cq, .md272qp], .choice(corners))]),
        Feature("00270", "Smart Crosshair", .gaming,
                summary: "Draws an aiming mark in the middle of the screen. Creator models use this slot for guide lines.",
                illustration: .crosshair, encoding: .base(100),
                [([.mpg273cqr, .mag321qr, .mag274qrx, .mag251rx, .mag401qr], crosshairIcons),
                 (.ps341wu, .choice(["Off", "Center", "Edge", "Scale V", "Scale H", "Line V", "Line H", "Grid", "Thirds", "3D Assistance"])),
                 (.mag, .choice(["Off"] + (1...6).map { "Red \($0)" } + (1...6).map { "White \($0)" }))]),
        Feature("00271", "Crosshair Colour", .gaming,
                summary: "Colour of the crosshair. Auto picks the colour that contrasts with the scene.",
                [([.mpg273cqr, .mag321qr, .mag274qrx], .choice(["White", "Red", "Auto"]))]),
    ]

    // MARK: - Professional

    private static let professional: [Feature] = [
        Feature(Code.proMode, "Pro Mode", .professional,
                summary: "Picture presets for work and video. sRGB, Adobe RGB and DCI-P3 limit colours to that standard for accurate editing. Choosing one replaces the Game Mode.",
                [([.mpg273cqr, .mag321qr, .mag401qr], .choice(["User", "Anti-Blue", "Movie", "Office", "sRGB", "Eco"])),
                 (.mag274qrx, .choice(["User", "Anti-Blue", "Movie", "Office", "sRGB", "Adobe RGB", "DCI-P3", "Eco"])),
                 (.md272qp, .choice(["Eco", "User", "sRGB", "Anti-Blue", "Movie", "Office", "Black & White"])),
                 ([.mag272Family, .mag251rx], .choice(["User", "Reader", "Cinema", "Designer", "HDR"])),
                 (.mag274qrfqd, .choice(["User", "Reader", "Cinema", "Office"])),
                 ([.mag274qrfqd16, .mag274qrfqd20], .choice(["User", "Reader", "Cinema", "Office", "sRGB", "Adobe RGB", "DCI-P3"])),
                 (.ps341wu, .choice(["User", "Adobe RGB", "DCI-P3", "sRGB", "HDR", "Cinema", "Reader", "Black & White",
                                     "DICOM", "Eye Care", "Calibration 1", "Calibration 2", "Calibration 3"])),
                 ([.mag321curv, .mag321cqr, .mag271cqr, .mag241Family, .mpg341cqr, .mpg27cq, .mag274r],
                  .choice(["User", "Reader", "Cinema", "Designer"]))]),
        Feature("00310", "Low Blue Light", .professional,
                summary: "Eye Saver. Shifts colours towards yellow to cut blue light, which is easier on the eyes at night.",
                illustration: .lowBlueLight,
                [(.all, offOn)]),
        Feature("00480", "Blue Light Filter", .professional,
                summary: "Hardware blue light reduction on creator models.",
                illustration: .lowBlueLight,
                [(.ps341wu, offOn)]),
        Feature("00240", "HDCR", .professional,
                summary: "High Dynamic Contrast Ratio. Adjusts contrast scene by scene so dark areas get darker and bright areas brighter. Brightness is locked while it is on. This is not real HDR.",
                illustration: .hdcr,
                [([.mag, .mpg, .mag321qr, .mag251rx, .mag274qrx, .md272qp, .mag401qr], offOn)]),
        Feature("00340", "Image Enhancement", .professional,
                summary: "Sharpens edges and fine detail. Strong levels can make text look rough.",
                illustration: .sharpness,
                [(.all, .choice(["Off", "Weak", "Medium", "Strong", "Strongest"]))]),
        Feature("00490", "Local Dimming", .professional,
                summary: "Dims parts of the backlight behind dark areas for deeper blacks.",
                illustration: .hdcr,
                [(.ps341wu, offOn)]),
        Feature("00460", "Gray Level", .professional,
                summary: "Fine tuning of mid-grey brightness.",
                [(.ps341wu, .range(0...20))]),
        Feature("004:0", "Gamma", .professional,
                summary: "How quickly shades go from dark to bright. 2.2 is the standard for most content.",
                [(.ps341wu, .choice(["1.8", "2.0", "2.2", "2.4", "2.6"]))]),
    ]

    // MARK: - Image

    private static let image: [Feature] = [
        Feature(Code.brightness, "Brightness", .image,
                summary: "Backlight strength. Locked while HDCR or MPRT is on.",
                illustration: .brightness,
                [(.all, percent)]),
        Feature("00410", "Contrast", .image,
                summary: "Difference between the darkest and brightest parts of the picture.",
                illustration: .contrast,
                [(.all, percent)]),
        Feature("00420", "Sharpness", .image,
                summary: "Edge sharpening. 0 shows the signal unchanged.",
                illustration: .sharpness,
                [(.all, .range(0...5))]),
        Feature("00430", "Colour Temperature", .image,
                summary: "Overall tint of white. Warm is yellowish, Cool is bluish. Custom unlocks the red, green and blue levels.",
                illustration: .colorTemperature,
                [(colorFamily, .choice(["Cool", "Normal", "Warm", "Custom"])),
                 (.ps341wu, .choice(["5000K", "5500K", "6500K", "7500K", "9300K", "10000K", "Custom"]))]),
        Feature("00431", "Red", .image, summary: "Red level for the Custom colour temperature.", [(colorFamily, percent)]),
        Feature("00432", "Green", .image, summary: "Green level for the Custom colour temperature.", [(colorFamily, percent)]),
        Feature("00433", "Blue", .image, summary: "Blue level for the Custom colour temperature.", [(colorFamily, percent)]),
        Feature("002:0", "Screen Size", .image,
                summary: "How a picture with a different shape is fitted: stretched to fill, or shown in its own aspect ratio with black bars.",
                illustration: .screenSize,
                [([.ps341wu, .mpg341cqr, .mag401qr], .choice(["Auto", "4:3", "16:9", "21:9", "1:1"])),
                 (.mag274qrx, .choice(["Auto", "4:3", "16:9", "1:1"])),
                 ([.mag272Family, .mpg273cqr, .mag321qr, .mag274r, .mag251rx, .md272qp], .choice(["Auto", "4:3", "16:9"])),
                 ([.mag321curv, .mag321cqr, .mag271cqr, .mpg27cq], .choice(["19\"", "24\"", "4:3", "16:9"]))]),
        Feature("004=0", "Zoom", .image,
                summary: "Magnifies part of the screen.",
                [(.ps341wu, offOn)]),
        Feature("004=1", "Zoom Location", .image,
                summary: "Area that Zoom magnifies.",
                [(.ps341wu, .choice(["Center"] + corners))]),
    ]

    // MARK: - Input

    private static let input: [Feature] = [
        Feature(Code.input, "Input Source", .input,
                summary: "Which connector the picture comes from.",
                profile: false,
                confirmation: "Switching away from the input this Mac uses turns this screen black.",
                [([.mag321curv, .mag272Family, .mag274Family, .ps341wu, .mpg341cqr, .mpg273cqr, .mag321qr, .mag251rx,
                   .mag274qrx, .mag401qr], fourInputs),
                 (.md272qp, .choice(["HDMI", "DisplayPort", "USB-C"])),
                 ([.mag321cqr, .mag271cqr, .mag241Family, .mpg27cq], threeInputs)]),
        Feature("00510", "Auto Scan", .input,
                summary: "Switches to whichever input has a signal.",
                profile: false,
                [([.mpg273cqr, .mag321qr, .mag274Family, .mag274qrx, .md272qp, .mag401qr], offOn)]),
        Feature("008>0", "KVM", .input,
                summary: "Shares the keyboard and mouse plugged into the monitor between two computers. Upstream is the USB-B port, USB-C is the USB-C port.",
                profile: false,
                confirmation: "Moving USB to the other computer disconnects this app. Use the Navi Key on the monitor to switch back.",
                [([.mpg273cqr, .mag321qr, .mag274qrx, .md272qp, .mag401qr], .choice(["Auto", "Upstream", "USB-C"]))]),
    ]

    // MARK: - Picture in picture

    private static let pictureInPicture: [Feature] = [
        Feature(Code.pictureInPicture, "PIP / PBP", .pictureInPicture,
                summary: "Shows two inputs at once: PIP puts a small window over the main picture, PBP splits the screen side by side. Adaptive-Sync and MPRT turn off.",
                illustration: .pictureInPicture, profile: false,
                [(pipFamily, .choice(["Off", "PIP", "PBP"])),
                 (creatorPIP, .choice(["Off", "PIP", "PBP ×2", "PBP ×3", "PBP ×4"]))]),
        Feature("00610", "PIP Source", .pictureInPicture,
                summary: "Input shown in the small window.", profile: false,
                [([.mag321curv, .mag274qrx], fourInputs),
                 ([.mag271cqr, .mag321cqr, .mpg27cq], threeInputs)]),
        Feature("00620", "Second Source", .pictureInPicture,
                summary: "Input shown in the second window.", profile: false,
                [([.mag321curv, .mag274qrx, .mag401qr, .ps341wu, .mpg341cqr], fourInputs),
                 ([.mag271cqr, .mag321cqr, .mpg27cq], threeInputs)]),
        Feature("00630", "PIP Size", .pictureInPicture,
                summary: "Size of the small window.", profile: false,
                [([.ps341wu, .mag321curv, .mag321cqr, .mag271cqr, .mpg341cqr, .mpg27cq, .mag274qrx, .mag401qr],
                  .choice(["Small", "Medium", "Large"]))]),
        Feature("00640", "PIP Location", .pictureInPicture,
                summary: "Corner of the small window.", profile: false,
                [([.mag274qrx, .mag401qr], cornersOrCustom),
                 ([.ps341wu, .mag321curv, .mag321cqr, .mag271cqr, .mpg341cqr, .mpg27cq], .choice(corners))]),
        Feature("006=0", "PBP Layout", .pictureInPicture,
                summary: "How the screen is split in PBP.", profile: false,
                [(.mag401qr, .choice(["Layout 1", "Layout 2"]))]),
        Feature("00611", "PBP Source 1", .pictureInPicture, summary: "Input on the left side.", profile: false,
                [(.mag401qr, fourInputs)]),
        Feature("00612", "PBP Source 2", .pictureInPicture, summary: "Input on the right side.", profile: false,
                [(.mag401qr, fourInputs)]),
        Feature("00670", "PBP Source 1", .pictureInPicture, summary: "Input in the first window.", profile: false,
                [(creatorPIP, fourInputs)]),
        Feature("00680", "PBP Source 2", .pictureInPicture, summary: "Input in the second window.", profile: false,
                [(creatorPIP, fourInputs)]),
        Feature("00690", "PBP Source 3", .pictureInPicture, summary: "Input in the third window.", profile: false,
                [(creatorPIP, fourInputs)]),
        Feature("006:0", "PBP Source 4", .pictureInPicture, summary: "Input in the fourth window.", profile: false,
                [(.ps341wu, fourInputs)]),
        Feature("006;0", "PBP Audio", .pictureInPicture, summary: "Input whose sound is played.", profile: false,
                [(creatorPIP, fourInputs)]),
        Feature("00650", "Swap Windows", .pictureInPicture,
                summary: "Swaps the main and second picture.", profile: false,
                [([.ps341wu, .mag321curv, .mag321cqr, .mag271cqr, .mpg341cqr, .mpg27cq, .mag274qrx, .mag401qr], .action)]),
        Feature("00660", "Audio Source", .pictureInPicture,
                summary: "Switches the sound to the other window.", profile: false,
                [([.mag321curv, .mag321cqr, .mag271cqr, .mpg27cq, .mag274qrx, .mag401qr], .action),
                 (creatorPIP, fourInputs)]),
    ]

    // MARK: - Navi Key

    private static let naviKey: [Feature] = [
        ("00900", "Navi Key Up"), ("00910", "Navi Key Down"), ("00920", "Navi Key Left"), ("00930", "Navi Key Right"),
    ].map { code, title in
        Feature(code, title, .naviKey,
                summary: "Shortcut opened by pushing the joystick on the back of the monitor in this direction.",
                profile: false, naviActions)
    }

    private static let naviActions: [(Series, Control)] = [
        (.mag401qr, .choice(["Off", "Brightness", "Game Mode", "Screen Assistance", "Alarm Clock", "Input Source",
                             "PIP / PBP", "Refresh Rate", "Info", "Night Vision", "Optix Scope", "KVM"])),
        (.mag274qrx, .choice(["Off", "Brightness", "Game Mode", "Smart Crosshair", "Alarm Clock", "Input Source",
                              "PIP / PBP", "Refresh Rate", "Info", "Night Vision", "Optix Scope", "KVM"])),
        (.mpg273cqr, .choice(["Off", "Brightness", "Game Mode", "Smart Crosshair", "Alarm Clock", "Input Source",
                              "Refresh Rate", "Info", "Night Vision", "KVM"])),
        (.mag321qr, .choice(["Off", "Brightness", "Game Mode", "Alarm Clock", "Smart Crosshair", "Input Source",
                             "Refresh Rate", "Info", "Night Vision", "KVM"])),
        (.mag272Family, .choice(["Off", "Brightness", "Game Mode", "Screen Assistance", "Alarm Clock", "Refresh Rate", "Info"])),
        (.mag241Family, .choice(["Off", "Brightness", "Game Mode", "Screen Assistance", "Alarm Clock", "Input Source", "Refresh Rate"])),
        (.mpg341cqr, .choice(["Off", "Brightness", "Game Mode", "Screen Assistance", "Alarm Clock", "Input Source",
                              "Refresh Rate", "Volume"])),
        ([.mag274Family, .mag251rx], .choice(["Off", "Brightness", "Game Mode", "Screen Assistance", "Alarm Clock",
                                              "Input Source", "Refresh Rate", "Info"])),
        ([.mag321curv, .mag321cqr, .mag271cqr, .mpg27cq], .choice(["Off", "Brightness", "Game Mode", "Screen Assistance",
                                                                   "Alarm Clock", "Input Source", "PIP", "Refresh Rate"])),
        (.ps341wu, .choice(["Off", "Brightness", "Pro Mode", "Screen Assistance", "Alarm Clock", "Input Source", "PIP",
                            "Zoom", "Info"])),
    ]

    // MARK: - Light and sound

    private static let lighting: [Feature] = [
        Feature("00860", "RGB LED", .lighting,
                summary: "Mystic Light: the LEDs on the back or bottom of the monitor.",
                [(.withRGBLED, offOn)]),
        Feature("008<0", "Ambient Light", .lighting,
                summary: "Adjusts the brightness to the room using the light sensor.",
                [(.mpg273cqr, .choice(["Off", "Auto", "Custom"]))]),
        Feature("008<3", "Ambient Brightness", .lighting,
                summary: "Brightness used when Ambient Light is Custom.",
                [(.mpg273cqr, percent)]),
        Feature("008<2", "Ambient RGB", .lighting,
                summary: "Lets the light sensor control the RGB LEDs too.",
                [(.mpg273cqr, offOn)]),
        Feature("00850", "Audio", .lighting,
                summary: "Sound output of the monitor, or which audio signal it plays.",
                [(.mag, offOn),
                 ([.ps341wu, .mpg341cqr, .mpg27cq], .choice(["Analog", "Digital"]))]),
        Feature("008=0", "Sound Tune", .lighting,
                summary: "Boosts footsteps and other quiet in-game sounds.",
                [(.mpg273cqr, offOn)]),
    ]

    // MARK: - Setting

    private static let system: [Feature] = [
        Feature("00800", "OSD Language", .system,
                summary: "Language of the on-screen menu. Change it with the buttons on the monitor.",
                profile: false, encoding: .mixed(100),
                [([.mag, .mag251rx, .mag274qrx, .md272qp, .mag401qr, .ps341wu], .readOnly())]),
        Feature("00810", "OSD Transparency", .system,
                summary: "How see-through the on-screen menu is.", profile: false,
                [(.all, .range(0...5))]),
        Feature("00820", "OSD Timeout", .system,
                summary: "How long the on-screen menu stays open without input.", profile: false,
                [(.mag401qr, .range(5...30, format: .seconds)),
                 (.all, .range(0...30, format: .seconds))]),
        Feature("00830", "Info on Screen", .system,
                summary: "Shows the input, resolution and mode briefly after a change.",
                illustration: .onScreenInfo,
                [([.ps341wu, .mag274Family, .mag251rx, .mpg273cqr, .mag321qr, .mag274qrx, .md272qp, .mag401qr], offOn)]),
        Feature("00880", "Power Button", .system,
                summary: "What the power button does: turn the monitor off, or put it in standby.", profile: false,
                [([.mpg273cqr, .mag321qr, .mag274Family, .mag251rx, .mag274qrx, .md272qp, .mag401qr], .choice(["Off", "Standby"]))]),
        Feature("008:0", "HDMI CEC", .system,
                summary: "Lets consoles and TV boxes on HDMI wake the monitor and switch to their input.", profile: false,
                [([.mpg273cqr, .mag321qr, .mag274qrfFamily, .mag274qrx, .md272qp, .mag401qr], offOn)]),
        Feature("008;0", "DP Overclocking", .system,
                summary: "Unlocks the highest refresh rate over DisplayPort.", profile: false,
                [(.mag401qr, offOn)]),
        Feature("00180", "Quick Charge", .system,
                summary: "Fast charging on the USB ports.", profile: false,
                [(.ps341wu, .readOnly())]),
    ]
}
