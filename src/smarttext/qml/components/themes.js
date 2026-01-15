function get(name) {
  switch (name) {
    case "White":
      return {
        // surfaces
        windowBg: "#f3f3f5",
        chromeBg: "#e9e9ee",
        railBg:   "#e7e7ec",
        cardBg:   "#ffffff",
        surface2: "#f6f6f9",

        // editor
        editorBg: "#ffffff",
        editorBorder: "#d6d6df",

        // borders
        border: "#d6d6df",
        borderStrong: "#c7c7d2",

        // text
        text: "#111111",
        textSoft: "#444444",
        textMuted: "#777777",

        // controls
        btnBg: "#e7e7ec",
        btnHover: "#dedee6",
        dangerHover: "#d44b4b",

        // tabs
        tabActiveBg: "#ffffff",
        tabInactiveBg: "#e4e4ea",

        // overlay
        overlayBottom: "#AA000000"
      }

    case "Purple":
      return {
        windowBg: "#18131f",
        chromeBg: "#231a2d",
        railBg:   "#1f1728",
        cardBg:   "#1a1422",
        surface2: "#120d18",

        editorBg: "#120d18",
        editorBorder: "#3b2b52",

        border: "#352747",
        borderStrong: "#4a3566",

        text: "#f0e9ff",
        textSoft: "#d8cfff",
        textMuted: "#a99ad6",

        btnBg: "#2a1f38",
        btnHover: "#352747",
        dangerHover: "#c0392b",

        tabActiveBg: "#120d18",
        tabInactiveBg: "#2a1f38",

        overlayBottom: "#AA000000"
      }

    case "Dark":
    default:
      return {
        windowBg: "#1e1e1e",
        chromeBg: "#2a2a2a",
        railBg:   "#1b1b1b",
        cardBg:   "#161616",
        surface2: "#111111",

        editorBg: "#111111",
        editorBorder: "#333333",

        border: "#2a2a2a",
        borderStrong: "#333333",

        text: "#eeeeee",
        textSoft: "#dddddd",
        textMuted: "#777777",

        btnBg: "#2a2a2a",
        btnHover: "#333333",
        dangerHover: "#c0392b",

        tabActiveBg: "#111111",
        tabInactiveBg: "#232323",

        overlayBottom: "#AA000000"
      }
  }
}
