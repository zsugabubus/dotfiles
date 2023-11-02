pub static XTERM_256: [[u8; 3]; 256] = {
    let mut palette = [[0; 3]; 256];

    // User palette.
    {
        let mut i = 0;
        while i < 16 {
            let c = if i < 8 { 0x80 } else { 0xff };
            palette[i] = [
                if i & 0x1 != 0 { c } else { 0 },
                if i & 0x2 != 0 { c } else { 0 },
                if i & 0x4 != 0 { c } else { 0 },
            ];
            i += 1;
        }
        palette[7] = [0xc0, 0xc0, 0xc0];
        palette[8] = [0x80, 0x80, 0x80];
    }

    // Cube colors.
    {
        let cube = {
            let mut v = [0; 6];
            v[0] = 0;
            let mut i = 1;
            while i < 6 {
                v[i] = 0x37 + 0x28 * i as u8;
                i += 1;
            }
            v
        };
        let mut i = 16;
        let mut r = 0;
        while r < 6 {
            let mut g = 0;
            while g < 6 {
                let mut b = 0;
                while b < 6 {
                    palette[i] = [cube[r], cube[g], cube[b]];
                    i += 1;
                    b += 1;
                }
                g += 1;
            }
            r += 1;
        }
    }

    // Grey scale.
    {
        let mut i = 16 + 6 * 6 * 6;
        let mut k = 0;
        while k < 24 {
            let c = (0x08 + 0x0a * k) as u8;
            palette[i] = [c, c, c];
            i += 1;
            k += 1;
        }
    }

    palette
};
