package tui

// skullHeader is the 14-line braille skull from home/.config/nvim/lua/plugins/snacks.lua
// (lines 29–42, byte-identical to the snacks dashboard preset header).
const skullHeader = `
⠄⠄⠄⠄⠄⠄⠄⠄⠄⣀⣠⣤⣤⣤⣤⣀⡀⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⣠⣤⢶⣻⣿⣻⣿⣿⣿⣿⣿⣿⣦⣤⣀⠄⠄⠄⠄⠄
⠄⠄⠄⠄⣼⣺⢷⣻⣽⣾⣿⢿⣿⣷⣿⣿⢿⣿⣿⣿⣇⠄⠄⠄⠄
⠄⠄⠠⡍⢾⣺⢽⡳⣻⡺⣽⢝⢗⢯⣻⢽⣻⣿⣿⣿⣿⢿⡄⠄⠄
⠄⠄⡨⣖⢹⠜⢅⢫⢊⢎⠜⢌⠣⢑⠡⣹⡸⣜⣯⣿⢿⣻⣷⠄⠄
⠄⠄⢜⢔⡹⡭⣪⢼⠽⠷⠧⣳⢘⢔⡝⠾⠽⢿⣷⣿⣟⢷⣟⠄⠄
⠄⠄⢸⢘⢼⠿⠟⠁⠄⠄⡀⠄⠃⠑⡌⠄⠄⠈⠙⠿⣷⢽⣻⠄⠄
⠄⠄⢌⠂⠅⠄⠄⠄⠄⠄⠄⡀⣲⣢⢂⠄⠄⠄⠄⠄⠈⣯⠏⠄⠄
⠄⠄⠐⠨⡂⠄⠄⠄⠄⠄⡀⡔⠋⢻⣤⡀⠄⠄⢀⠄⢸⣯⠇⠄⠄
⠄⠄⠈⣕⠝⠒⠄⠄⠒⢉⠪⠄⠄⠄⢿⠜⠑⠢⠠⡒⡺⣿⠖⠄⠄
⠄⠄⠄⠐⠅⠁⡀⠄⠐⢔⠁⠄⠄⠄⢀⢇⢌⠄⠄⠄⠸⠕⠄⠄⠄
⠄⠄⠄⠄⠂⠄⠄⠨⣔⡝⠼⡄⠂⣦⡆⣿⣲⠐⠑⠁⠄⠃⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⠃⢫⢛⣙⡊⣜⣏⡝⣝⠆⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⠈⠈⠁⠁⠁⠈⠈⠊⠄⠄⠄⠄⠄⠄⠄⠄⠄`

// RenderHeader returns the skull header tinted with the palette title color,
// followed by the subtitle on a new line styled with the palette subtitle color.
// The width parameter is retained for API stability but no longer triggers
// horizontal centering; the global Padding(1, 2, 0, 2) in View() handles the gutter.
func RenderHeader(p Palette, subtitle string, width int) string {
	_ = width
	s := getStyles(p)
	skull := s.title.Render(skullHeader)
	sub := s.subtitle.Render(subtitle)
	return skull + "\n" + sub
}
