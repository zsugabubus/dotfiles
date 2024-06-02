for (const [name, colors] of Object.entries(require('tailwindcss/colors'))) {
	if (!name.match(/[A-Z]/) && typeof(colors) === 'object') {
		for (const [shade, color] of Object.entries(colors)) {
			console.log(`${name}-${shade},${color}`);
		}
	}
}
