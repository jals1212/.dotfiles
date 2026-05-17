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
// When width > 0, the header is centered horizontally.
func RenderHeader(p Palette, subtitle string, width int) string {
	s := getStyles(p)
	skull := s.title.Render(skullHeader)
	sub := s.subtitle.Render(subtitle)
	content := skull + "\n" + sub
	if width > 0 {
		return CenterHorizontally(content, width)
	}
	return content
}
