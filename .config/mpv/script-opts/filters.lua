return {
	af = {
		'!lavfi=[asoftclip]',
		-- https://ffmpeg.org/ffmpeg-filters.html#dynaudnorm
		'!lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]',
		'!afftdn=nr=40',
		'!lavfi=[dynaudnorm=f=400:g=23:r=0.9:p=0.5]',
		-- http://k.ylo.ph/2016/04/04/loudnorm.html
		'!highpass=f=130',
		'!lowpass=f=6000',
		'!highpass=f=195',
		'!highpass=f=650',
		'!lavfi=[pan=mono|c0=c1]',
	},
	vf = {
		'!hflip',
		'!negate',
	},
}
