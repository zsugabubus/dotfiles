import assert from "node:assert/strict";
import { it, describe, before, after, mock } from "node:test";
import http from "node:http";
import zlib from "node:zlib";
import child_process from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import crypto from "node:crypto";

const exePath = `${process.cwd()}/transmission-tui`;

const readToString = async (stream) => {
	return Buffer.concat(await Array.fromAsync(stream)).toString();
};

const getRandomHexString = (n) => Buffer.from(crypto.randomBytes(n)).toString("hex");

const sleep = (time) => new Promise((resolve) => setTimeout(resolve, time));

const getOptions = (options, defaults) => Object.assign(Object.seal(defaults), options);

const toRegExp = (s) =>
	typeof s === "string" ? new RegExp(s.replace(/([.*?|()[\]])/g, "\\$1")) : s;

const retryAssert = async (fn, timeout) => {
	const signal = AbortSignal.timeout(timeout);
	const signalled = new Promise((resolve) => {
		signal.addEventListener("abort", () => {
			resolve();
		});
	});

	for (let retryDelay = 50; ; retryDelay *= 2) {
		await Promise.race([signalled, sleep(retryDelay)]);

		if (signal.aborted) {
			break;
		}

		try {
			await fn();
			return;
		} catch (err) {
			if (err instanceof assert.AssertionError) {
				continue;
			}
			throw err;
		}
	}

	await fn();
};

const createTestDir = async () => {
	const path = `${os.tmpdir()}/transmission-tui-test`;
	await fs.mkdir(path).catch(() => {
		// Ignore.
	});
	return path;
};

const createTmux = async (options) => {
	options = getOptions(options, { hostDir: undefined });

	const socketName = "tmux.socket";
	const socketPath = `${options.hostDir}/${socketName}`;
	await fs.rm(socketPath).catch(() => {
		// Ignore.
	});

	const child = child_process.spawn(
		"bwrap",
		[
			"--as-pid-1",
			"--new-session",
			"--die-with-parent",
			"--unshare-all",
			"--share-net",
			"--clearenv",
			...["--setenv", "LANG", "en_US.UTF-8"],
			...["--setenv", "EDITOR", "nvim"],
			...["--hostname", "test"],
			...["--dev", "/dev"],
			...["--proc", "/proc"],
			...["--ro-bind", "/bin", "/bin"],
			...["--ro-bind", "/usr", "/usr"],
			...["--ro-bind", "/lib", "/lib"],
			...["--ro-bind", "/lib64", "/lib64"],
			...["--dir", "/tmp"],
			...["--ro-bind", exePath, "/exe"],
			...["--bind", options.hostDir, "/host"],
			...["--dir", "/cwd"],
			...["tmux", "-D", "-S", `/host/${socketName}`],
		],
		{
			stdio: ["ignore", "inherit", "inherit"],
		},
	);

	await retryAssert(async () => {
		assert.ok(
			await fs.access(socketPath).then(
				() => true,
				() => false,
			),
		);
	}, 1000);

	const close = () => {
		child.kill("SIGKILL");
	};

	const command = async (...args) => {
		const child = child_process.spawn(
			"tmux",
			["-S", `${options.hostDir}/tmux.socket`, "-N", ...args],
			{
				stdio: ["ignore", "pipe", "inherit"],
			},
		);

		return await readToString(child.stdout);
	};

	await command(
		...["set-option", "-g", "remain-on-exit", "on", ";"],
		...["set-option", "-g", "remain-on-exit-format", "[exited #{pane_dead_status}]"],
	);

	return {
		command,
		close,
	};
};

const createTransmission = () => {
	let lastTorrentId = 0;

	const sessionInfo = Object.seal({
		version: "3.00 (fake)",
		"rpc-version": 16,
		"speed-limit-down-enabled": false,
		"speed-limit-down": 0,
		"alt-speed-down": 0,
		"alt-speed-enabled": false,
		"speed-limit-up-enabled": false,
		"speed-limit-up": 0,
		"alt-speed-up": 0,
		"download-dir": "/session/download/dir",
	});

	const sessionStats = Object.seal({
		downloadSpeed: 0,
		uploadSpeed: 0,
		"current-stats": Object.seal({
			downloadedBytes: 0,
			uploadedBytes: 0,
		}),
		"cumulative-stats": Object.seal({
			downloadedBytes: 0,
			uploadedBytes: 0,
		}),
	});

	const torrents = [];

	const addTorrent = (fields) => {
		const id = ++lastTorrentId;
		const torrent = Object.assign(
			Object.seal({
				id,
				eta: 0,
				sizeWhenDone: 0,
				isStalled: false,
				isFinished: false,
				labels: [],
				hashString: `HASH_${id}_${getRandomHexString(10)}`,
				name: `Torrent ${id}`,
				rateUpload: 0,
				percentDone: 0,
				uploadLimit: 0,
				rateDownload: 0,
				errorString: 0,
				error: 0,
				downloadLimit: 0,
				downloadLimited: 0,
				uploadRatio: 0,
				recheckProgress: 0,
				peersSendingToUs: 0,
				seedRatioMode: 0,
				seedRatioLimit: 0,
				peersConnected: 0,
				peersGettingFromUs: 0,
				queuePosition: 0,
				uploadLimited: 0,
				status: 0,
				files: [],
				fileStats: [],
				downloadDir: "/torrent/download/dir",
				peers: [],
			}),
			fields,
		);
		torrents.push(torrent);
		return torrent;
	};

	const recentlyRemovedTorrentIds = [];

	const removeTorrentById = (id) => {
		const index = torrents.findIndex((torrent) => torrent.id === id);
		assert.ok(index >= 0);
		torrents.splice(index, 1);
		recentlyRemovedTorrentIds.push(id);
	};

	const findTorrentById = (id) => torrents.find((torrent) => torrent.id === id);

	const findTorrentByHash = (hash) => torrents.find((torrent) => torrent.hashString === hash);

	const getTorrentHash = (id) => findTorrentById(id).hashString;

	return {
		torrents,
		addTorrent,
		removeTorrentById,
		findTorrentByHash,
		getTorrentHash,
		sessionStats,
		sessionInfo,
		recentlyRemovedTorrentIds,
	};
};

class RPCError extends Error {}

const createTransmissionRPC = async (options) => {
	options = getOptions(options, {
		rpcHost: "127.0.0.1",
		rpcPort: 0,
		rpcPath: "/transmission/rpc",
		rpcUsername: "",
		rpcPassword: "",
		rpcAuthorization: "",
		torrents: [],
	});

	const getRandomSessionId = () => getRandomHexString(20);

	const transmission = createTransmission();
	let sessionId = getRandomSessionId();

	const renewSessionId = () => {
		sessionId = getRandomSessionId();
	};

	for (const torrent of options.torrents) {
		transmission.addTorrent(torrent);
	}

	const project = (input, fields) =>
		fields.reduce((output, field) => {
			output[field] = input[field];
			return output;
		}, {});

	const rpcHandlers = {
		"session-get": (args) => project(transmission.sessionInfo, args.fields),
		"session-stats": () => ({
			...transmission.sessionStats,
			torrentCount: transmission.torrents.length,
			pausedTorrentCount: transmission.torrents.reduce(
				(n, torrent) => n + (torrent.status === 0 ? 1 : 0),
				0,
			),
		}),
		"torrent-get": (args) => {
			if (args.ids === "recently-active") {
				return {
					torrents: transmission.torrents.map((torrent) => project(torrent, args.fields)),
					removed: transmission.recentlyRemovedTorrentIds,
				};
			}
			if (args.ids) {
				return {
					torrents: args.ids
						.map(transmission.findTorrentByHash)
						.filter(Boolean)
						.map((torrent) => project(torrent, args.fields)),
				};
			}
			return {
				torrents: transmission.torrents.map((torrent) => project(torrent, args.fields)),
			};
		},
	};

	const setRPCHandler = (methodName, fn) => {
		const handler = mock.fn(fn);

		rpcHandlers[methodName] = handler;

		const expectRequests = (...requests) => {
			assert.deepStrictEqual(
				handler.mock.calls.map((call) => call.arguments[0]),
				requests,
			);
			handler.mock.resetCalls();
		};

		after(() => {
			assert.strictEqual(
				handler.mock.callCount(),
				0,
				`no requests after last ${expectRequests.name}`,
			);
		});

		return { expectRequests };
	};

	const server = http.createServer(async (request, response) => {
		const { method, headers, url } = request;

		assert.strictEqual(method, "POST");

		assert.strictEqual(url, options.rpcPath);

		assert.strictEqual(headers["host"], `${options.rpcHost}:${port}`);
		assert.strictEqual(headers["content-type"], "application/json");
		assert.ok(headers["accept-encoding"].split(", ").includes("gzip"));

		assert.strictEqual(headers["authorization"] ?? "", options.rpcAuthorization);

		const clientSessionId = headers["x-transmission-session-id"];

		if (clientSessionId !== sessionId) {
			console.log("< Session ID: %o", clientSessionId);
			console.log("> Session ID: %o", sessionId);

			response.writeHead(409, {
				"x-transmission-session-id": sessionId,
			});
			response.end("");
			return;
		}

		const rpcRequest = JSON.parse(await readToString(request));
		console.log("< %o", rpcRequest);

		const rpcResponse = await (async () => {
			const handler = rpcHandlers[rpcRequest.method];
			assert.ok(handler, `Unknown method: ${rpcRequest.method}`);
			try {
				return {
					arguments: await handler(rpcRequest.arguments),
					result: "success",
				};
			} catch (err) {
				if (err instanceof RPCError) {
					return {
						result: err.message,
					};
				}
				throw err;
			}
		})();
		console.log("> %o", rpcResponse);

		response.writeHead(200, {
			"content-type": "application/json",
			"content-encoding": "gzip",
		});
		response.end(zlib.deflateSync(JSON.stringify(rpcResponse)));
	});

	const close = () => {
		server.close();
	};

	await new Promise((resolve) => {
		server.listen(
			{
				host: options.rpcHost,
				port: options.rpcPort,
			},
			resolve,
		);
	});

	const { address, port } = server.address();

	console.log("Transmission RPC listening on %s:%d.", address, port);

	return {
		rpcPort: port,
		setRPCHandler,
		...transmission,
		renewSessionId,
		close,
	};
};

const createTUI = async (options) => {
	const chars = {
		topLeft: "┌",
		topRight: "┐",
		horizontal: "─",
		vertical: "│",
		bottomLeft: "└",
		bottomRight: "┘",
		fill: " ",
	};
	const slowTimeout = 2000;
	const fastTimeout = 500;

	options = getOptions(options, {
		width: 100,
		height: 20,
		args: [],
		env: {},
		tmux: undefined,
	});

	console.log("Start TUI with %o.", options.args);

	const pane = (
		await options.tmux.command(
			"new-session",
			"-d",
			"-P",
			...["-F", "#{pane_id}"],
			...["-c", "/cwd"],
			...["-x", options.width],
			...["-y", options.height],
			...Object.entries(options.env).map(([name, value]) => `-e${name}=${value}`),
			"/exe",
			...options.args,
		)
	).trim();

	const close = async () => {
		await options.tmux.command("kill-pane", "-t", pane);
	};

	const captureScreen = async () => {
		const output = await options.tmux.command(
			"capture-pane",
			"-p",
			"-t",
			pane,
			";",
			"display-message",
			"-p",
			"-t",
			pane,
			"#{pane_width}\n#{pane_height}\n#{cursor_y}\n#{cursor_x}",
		);
		const lines = output.split("\n");
		assert.strictEqual(lines.pop(), "");
		const col = parseInt(lines.pop());
		const row = parseInt(lines.pop());
		const height = parseInt(lines.pop());
		const width = parseInt(lines.pop());
		const string = lines.join("\n");
		return { col, row, height, width, lines, string };
	};

	const printScreen = (title, { col, row, height, width, lines }) => {
		console.log("%s of pane %s, %dx%d @ %d,%d:", title, pane, height, width, row + 1, col + 1);
		const linesWithAttrs = lines.map((line, y) =>
			[...line.padEnd(width, chars.fill)]
				.map((c, x) => {
					if (x === line.length) {
						c = "\x1b[37m$\x1b[m";
					}
					if (y === row && x === col) {
						c = `\x1b[7m${c}\x1b[m`;
					}
					return c;
				})
				.join(""),
		);
		console.log(
			[
				chars.topLeft + chars.horizontal.repeat(width) + chars.topRight,
				...linesWithAttrs.map((s) => chars.vertical + s + chars.vertical),
				chars.bottomLeft + chars.horizontal.repeat(width) + chars.bottomRight,
			].join("\n"),
		);
	};

	const parseScreen = async ({ lines }) => {
		lines = [...lines];

		const parseWindow = (lines) => {
			let header = lines.shift();

			while (lines.at(-1) === "~") {
				lines.pop();
			}

			const parseColumn = (start, end) => {
				return {
					title: header.slice(start, end).trim(),
					values: lines.map((line) => line.slice(start, end).trim()),
				};
			};

			const columnList = [];
			let columnStart = 1;

			for (const match of [...header.matchAll(/ +(?=[A-Z])/g)].slice(1)) {
				const columnEnd = (() => {
					const n = match[0].length;
					const start = match.index;
					const center = start + Math.floor(n / 2);
					for (let i = 0; i < n; i++) {
						const zigzag = i % 2 === 0 ? i / 2 : -(i + 1) / 2;
						const column = center + zigzag;
						if (lines.every((line) => line.at(column) === " ")) {
							return column;
						}
					}
					assert.fail();
				})();
				columnList.push(parseColumn(columnStart, columnEnd));
				columnStart = columnEnd;
			}

			columnList.push(parseColumn(columnStart));

			const rows = lines.map((_, i) =>
				Object.fromEntries(columnList.map((column) => [column.title, column.values[i]])),
			);
			const columns = Object.fromEntries(columnList.map((column) => [column.title, column.values]));

			assert.strictEqual(Object.keys(columns).length, columnList.length, "Unique column names");

			if (lines.length > 0) {
				assert.strictEqual(
					lines.reduce((n, line) => n + (line.at(0) === "*" ? 1 : 0), 0),
					1,
				);
			}
			const current = lines.length === 0 ? null : lines.findIndex((line) => line.at(0) === "*");

			return { columnList, columns, rows, current };
		};

		const parseStatusline = (line) => {
			const parseUpDown = (s) => {
				const parts = [null, null, ...s.split("  ", 3)].slice(-3);
				const currentParts = parts[0] === null ? [null] : parts[0].split("/", 2);
				return {
					speed: currentParts[0],
					speedLimit: currentParts[1] ?? null,
					session: parts[1],
					total: parts[2],
				};
			};

			const parseNumber = (s) => {
				const n = +s;
				assert.ok(!Number.isNaN(n));
				return n;
			};

			const [_, cursorStr, lastStr, totalStr, leftMessage, downStr, upStr, message] = line.match(
				/^\[(\d+)\/(\d+)(?: \((\d+)\))?\](?: ([^|]*?))? \| Down +([^|]*) \| Up +([^|]*) \| (.*)$/,
			);

			return {
				pos: {
					cursor: parseNumber(cursorStr),
					last: parseNumber(lastStr),
					total: totalStr === undefined ? null : parseNumber(totalStr),
				},
				paused:
					leftMessage === undefined ? null : parseNumber(leftMessage.match(/^(\d+) paused$/)?.[1]),
				down: parseUpDown(downStr),
				up: parseUpDown(upStr),
				message,
			};
		};

		return {
			...parseStatusline(lines.pop()),
			details: (() => {
				const start = lines.findIndex((line) => line.match(/Wanted|Client|Tier/));
				if (start <= 0) return;
				return parseWindow(lines.splice(start));
			})(),
			torrents: parseWindow(lines),
		};
	};

	const feed = async (...keys) => {
		console.log("Feed %o.", keys);
		await options.tmux.command("send-keys", "-t", pane, "--", ...keys);
	};

	const expectWithTimeout = async (spec, timeout) => {
		const defaultUpDown = {
			speed: null,
			speedLimit: null,
			session: null,
			total: "",
		};
		const assertWindowMatches = (parsedWindow, spec, defaultColumnName) => {
			if (spec === undefined) return;
			assert.deepStrictEqual(
				parsedWindow.rows.map((row, index) => {
					if (typeof spec[index] === "string") return row[defaultColumnName];
					return Object.keys(spec[index] ?? {}).reduce((obj, columnName) => {
						obj[columnName] = row[columnName] ?? null;
						return obj;
					}, {});
				}),
				spec,
			);
		};
		await retryAssert(async () => {
			const screen = await captureScreen();
			printScreen("Screenshot", screen);
			if (typeof spec === "string" || spec instanceof RegExp) {
				assert.match(screen.string, toRegExp(spec));
			} else if (Array.isArray(spec)) {
				for (const needle of spec) {
					assert.match(screen.string, toRegExp(needle));
				}
			} else {
				const { pos, paused, down, up, message, currentTorrent, torrents, peers, files, ...rest } =
					spec;
				assert.deepStrictEqual(rest, {}, "Unknown properties");
				const parsed = await parseScreen(screen);
				if (pos !== undefined) assert.deepStrictEqual(parsed.pos, { total: null, ...pos });
				if (paused !== undefined) assert.deepStrictEqual(parsed.paused, paused);
				if (down !== undefined) assert.deepStrictEqual(parsed.down, { ...defaultUpDown, ...down });
				if (up !== undefined) assert.deepStrictEqual(parsed.up, { ...defaultUpDown, ...up });
				if (message !== undefined) assert.deepStrictEqual(parsed.message, message);
				if (currentTorrent !== undefined)
					assert.deepStrictEqual(parsed.torrents.current, currentTorrent);
				assertWindowMatches(parsed.torrents, torrents, "Name");
				assertWindowMatches(parsed.details, peers, "Client");
				assertWindowMatches(parsed.details, files, "Name");
			}
		}, timeout);
	};

	const expectSlow = async (spec, ...rest) => {
		assert.deepStrictEqual(rest, [], "Too much arguments");
		await expectWithTimeout(spec, slowTimeout);
	};

	const expect = async (spec, ...rest) => {
		assert.deepStrictEqual(rest, [], "Too much arguments");
		await expectWithTimeout(spec, fastTimeout);
	};

	return { close, expect, expectSlow, feed };
};

let tmux;
// WTF: When there are some tests but --test-name-pattern runs zero tests: after() runs before before() resolves.
// WTF: When there are zero tests: before() runs but after() never.
let didAfter = false;
before(async () => {
	tmux = await createTmux({
		hostDir: await createTestDir(),
	});
	if (didAfter) {
		tmux.close();
	}
});
after(() => {
	didAfter = true;
	tmux?.close();
});

const createTestEnvironment = async (options) => {
	options = getOptions(options, {
		transmission: undefined,
		tui: undefined,
	});

	const {
		close: closeRPC,
		rpcPort,
		...rpcControl
	} = await createTransmissionRPC(options.transmission);

	const { close: closeTUI, ...tuiControl } = await createTUI({
		tmux,
		args: [rpcPort],
		...(typeof options.tui === "function" ? options.tui(rpcPort) : options.tui),
	});

	const close = async () => {
		await closeTUI();
		closeRPC();
	};

	const shell = async (cmd) => {
		const result = await tmux.command("if-shell", cmd, "display-message -p success");
		assert.strictEqual(result, "success\n");
	};

	after(() => close());

	return {
		...rpcControl,
		...tuiControl,
		shell,
	};
};

const vimUncommentAll = [":%s/^# *//", "Enter"];
const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;
const percentColumnCases = [
	[0, ""],
	[0.00001, "0.00%"],
	[0.0001, "0.01%"],
	[0.00899, "0.89%"],
	[0.00999, "0.99%"],
	[0.01, "1.00%"],
	[0.09999, "9.99%"],
	[0.1, "10.0%"],
	[0.89999, "89.9%"],
	[0.99999, "99.9%"],
	[1, "100%"],
];
const ratioColumnCases = [
	[0, ""],
	[0.00001, "0.0"],
	[0.09999, "0.0"],
	[0.1, "0.1"],
	[0.79999, "0.7"],
	[0.89999, "0.8"],
	[0.99999, "0.9"],
	[1, "1.0"],
];
const sizeColumnCases = [
	[0, ""],
	[0.999, "0B"],
	[1, "1B"],
	[1023, "1023B"],
	[KiB, "1.0K"],
	[KiB + 1, "1.1K"],
	[MiB, "1.0M"],
	[MiB + 1, "1.1M"],
	[1.9 * MiB, "1.9M"],
	[1.9 * MiB + 1, "2.0M"],
	[GiB, "1.0G"],
	[GiB + 1, "1.1G"],
	[10 * GiB, "10.0G"],
	[10 * GiB + 1, "10.1G"],
	[100 * GiB, "100G"],
	[100 * GiB + 1, "101G"],
	[100000 * GiB, "100000G"],
];
const secondsColumnCases = [
	[0, ""],
	[1, "1s"],
	[59, "59s"],
	[60, "1m"],
	[61, "2m"],
	[120, "2m"],
	[121, "3m"],
	[60 * 60, "60m"],
	[24 * 60 * 60, "24h"],
	[7 * 24 * 60 * 60, "7d"],
];

describe("self-test", () => {
	it("unknown options", async () => {
		const propertyError = { message: /Cannot add property/ };
		await assert.rejects(() => createTestEnvironment({ bad: {} }), propertyError);
		await assert.rejects(() => createTestEnvironment({ transmission: { bad: {} } }), propertyError);
		await assert.rejects(
			() => createTestEnvironment({ transmission: { torrents: [{ bad: {} }] } }),
			propertyError,
		);
		await assert.rejects(() => createTestEnvironment({ rpc: { bad: {} } }), propertyError);
		const t = await createTestEnvironment({ transmission: { torrents: [{}] } });
		assert.throws(() => {
			t.findTorrentByHash(t.getTorrentHash(1)).bad = 0;
		}, propertyError);
		assert.throws(() => {
			t.sessionInfo.bad = 0;
		}, propertyError);
		assert.throws(() => {
			t.sessionStats.bad = 0;
		}, propertyError);
		await assert.rejects(() => t.shell("false"), assert.AssertionError);
	});

	it("expect", async () => {
		const t = await createTestEnvironment({ transmission: { torrents: [{}, {}] } });
		await assert.rejects(() => t.expect({ x: {} }), assert.AssertionError);
		await assert.rejects(
			() => t.expect({ torrents: ["Torrent 2", "Torrent 1"] }),
			assert.AssertionError,
		);
		await assert.rejects(() => t.expect("Torrent 123"), assert.AssertionError);
		await assert.rejects(() => t.expect("Torrent 1", "Extra"), {
			message: /Too much arguments/,
		});
	});
});

it("connects to Transmission's RPC server by default", async (test) => {
	const defaultPort = 9091;

	const portFree = await new Promise((resolve) => {
		const server = http.createServer(() => {});
		server.on("error", () => {
			resolve(false);
		});
		server.listen(defaultPort, () => {
			server.close();
			resolve(true);
		});
	});
	if (!portFree) {
		test.skip(`Port ${defaultPort} is in use.`);
		return;
	}

	const t = await createTestEnvironment({
		transmission: {
			rpcPort: defaultPort,
			rpcPath: "/transmission/rpc",
			torrents: [{}],
		},
		tui: {
			args: [],
		},
	});
	await t.expect({ torrents: ["Torrent 1"] });
});

it("allows connecting to custom port", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [{}],
		},
		tui: (port) => ({
			args: [port],
		}),
	});
	await t.expect({ torrents: ["Torrent 1"] });
});

it("allows connecting to custom hostname and port", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [{}],
			rpcHost: "127.1.2.3",
		},
		tui: (port) => ({
			args: [`127.1.2.3:${port}`],
		}),
	});
	await t.expect({ torrents: ["Torrent 1"] });
});

it("allows connecting to custom hostname, port and path", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [{}],
			rpcHost: "127.1.2.3",
			rpcPath: "/custom/path/rpc",
		},
		tui: (port) => ({
			args: [`http://127.1.2.3:${port}/custom/path/`],
		}),
	});
	await t.expect({ torrents: ["Torrent 1"] });
});

it("allows username and password authentication via $TR_AUTH", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [{}],
			rpcAuthorization: `Basic ${Buffer.from("myusername:mypassword").toString("base64")}`,
		},
		tui: {
			env: {
				TR_AUTH: "myusername:mypassword",
			},
		},
	});
	await t.expect({ torrents: ["Torrent 1"] });
});

it("handles expired CSRF token", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}] },
	});
	await t.expect({ torrents: ["Torrent 1"] });
	t.renewSessionId();
	t.addTorrent({});
	await t.feed("r");
	await t.expect({ torrents: ["Torrent 1", "Torrent 2"] });
});

it("renders versions on startup", async () => {
	const t = await createTestEnvironment();
	await t.expect({
		message: `Transmission v${t.sessionInfo.version}, RPC v${t.sessionInfo["rpc-version"]}, press ? for help`,
	});
});

it("renders and periodically updates current speed, session bytes and all-time bytes", async () => {
	const t = await createTestEnvironment();
	t.sessionStats.downloadSpeed = 1;
	t.sessionStats["current-stats"].downloadedBytes = 1 * KiB;
	t.sessionStats["cumulative-stats"].downloadedBytes = 1 * MiB;
	t.sessionStats.uploadSpeed = 3;
	t.sessionStats["current-stats"].uploadedBytes = 3 * KiB;
	t.sessionStats["cumulative-stats"].uploadedBytes = 3 * MiB;
	await t.expect({
		down: { speed: "1B", session: "1.0K", total: "1.0M" },
		up: { speed: "3B", session: "3.0K", total: "3.0M" },
	});
	t.sessionStats.downloadSpeed *= 2;
	t.sessionStats["current-stats"].downloadedBytes *= 2;
	t.sessionStats["cumulative-stats"].downloadedBytes *= 2;
	t.sessionStats.uploadSpeed *= 2;
	t.sessionStats["current-stats"].uploadedBytes *= 2;
	t.sessionStats["cumulative-stats"].uploadedBytes *= 2;
	await t.expectSlow({
		down: { speed: "2B", session: "2.0K", total: "2.0M" },
		up: { speed: "6B", session: "6.0K", total: "6.0M" },
	});
});

it("doesn't render download speed and session downloaded bytes when zero", async () => {
	const t = await createTestEnvironment();
	t.sessionStats["cumulative-stats"].downloadedBytes = 1;
	t.sessionStats.uploadSpeed = 2;
	t.sessionStats["current-stats"].uploadedBytes = 3;
	t.sessionStats["cumulative-stats"].uploadedBytes = 4;
	await t.expect({
		down: { speed: null, session: null, total: "1B" },
		up: { speed: "2B", session: "3B", total: "4B" },
	});
});

describe("renders upload speed in fixed width", async () => {
	const A = "Up          1B";
	const B = "Up 1000.0K  1B";
	assert.strictEqual(A.length, B.length);

	const createTest = (uploadSpeed, text) => async () => {
		const t = await createTestEnvironment();
		t.sessionStats.uploadSpeed = uploadSpeed;
		t.sessionStats["current-stats"].uploadedBytes = 1;
		t.sessionStats["cumulative-stats"].uploadedBytes = 2;
		await t.expect(text);
	};

	it("when upload speed is zero", createTest(0, A));
	it("when upload speed isn't zero", createTest(1000 * KiB, B));
});

it("renders download speed limit when enabled", async () => {
	const t = await createTestEnvironment();
	t.sessionInfo["speed-limit-down-enabled"] = true;
	t.sessionInfo["speed-limit-down"] = 1;
	t.sessionInfo["speed-limit-up"] = 9;
	t.sessionStats["current-stats"].downloadedBytes = 2;
	t.sessionStats["current-stats"].uploadedBytes = 3;
	await t.expect({
		down: { speed: "", speedLimit: "1000B", session: "2B" },
		up: { speed: null, speedLimit: null, session: "3B" },
	});
});

it("renders upload speed limit when enabled", async () => {
	const t = await createTestEnvironment();
	t.sessionInfo["speed-limit-up-enabled"] = true;
	t.sessionInfo["speed-limit-down"] = 9;
	t.sessionInfo["speed-limit-up"] = 1;
	t.sessionStats["current-stats"].downloadedBytes = 2;
	t.sessionStats["current-stats"].uploadedBytes = 3;
	await t.expect({
		down: { speed: null, speedLimit: null, session: "2B" },
		up: { speed: "", speedLimit: "1000B", session: "3B" },
	});
});

it("renders alternate speed limits when enabled", async () => {
	const t = await createTestEnvironment();
	t.sessionInfo["alt-speed-enabled"] = true;
	t.sessionInfo["alt-speed-down"] = 1;
	t.sessionInfo["alt-speed-up"] = 1000;
	t.sessionStats.downloadSpeed = 2;
	t.sessionStats["current-stats"].downloadedBytes = 3;
	t.sessionStats["current-stats"].uploadedBytes = 4;
	await t.expect({
		down: { speed: "2B", speedLimit: "1000B", session: "3B" },
		up: { speed: "", speedLimit: "976.6K", session: "4B" },
	});
});

it("renders alternate speed limits when normal speed limits are also enabled", async () => {
	const t = await createTestEnvironment();
	t.sessionInfo["alt-speed-enabled"] = true;
	t.sessionInfo["alt-speed-down"] = 1;
	t.sessionInfo["alt-speed-up"] = 1;
	t.sessionInfo["speed-limit-down-enabled"] = true;
	t.sessionInfo["speed-limit-down"] = 9;
	t.sessionInfo["speed-limit-up-enabled"] = true;
	t.sessionInfo["speed-limit-up"] = 9;
	t.sessionStats.downloadSpeed = 2;
	t.sessionStats["current-stats"].downloadedBytes = 3;
	t.sessionStats["current-stats"].uploadedBytes = 3;
	await t.expect({
		down: { speed: "2B", speedLimit: "1000B", session: "3B" },
		up: { speed: "", speedLimit: "1000B", session: "3B" },
	});
});

it("periodically updates speed limits", async () => {
	const t = await createTestEnvironment();
	t.sessionInfo["alt-speed-enabled"] = true;
	t.sessionInfo["alt-speed-down"] = 1;
	t.sessionInfo["alt-speed-up"] = 1;
	t.sessionInfo["speed-limit-down"] = 2;
	t.sessionInfo["speed-limit-up"] = 2;
	t.sessionStats.downloadSpeed = 1;
	t.sessionStats["current-stats"].downloadedBytes = 10;
	t.sessionStats["current-stats"].uploadedBytes = 10;
	await t.expect({
		down: { speed: "1B", speedLimit: "1000B", session: "10B" },
		up: { speed: "", speedLimit: "1000B", session: "10B" },
	});
	t.sessionInfo["alt-speed-enabled"] = false;
	t.sessionInfo["speed-limit-down-enabled"] = true;
	t.sessionInfo["speed-limit-up-enabled"] = true;
	t.sessionInfo["speed-limit-down"] = 3;
	t.sessionInfo["speed-limit-up"] = 4;
	await t.expectSlow({
		down: { speed: "1B", speedLimit: "3.0K", session: "10B" },
		up: { speed: "", speedLimit: "4.0K", session: "10B" },
	});
});

it("renders torrents sorted by name", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{ name: "Torrent D" },
				{ name: "Torrent B" },
				{ name: "Torrent A" },
				{ name: "Torrent C" },
			],
		},
	});
	await t.expect({
		torrents: ["Torrent A", "Torrent B", "Torrent C", "Torrent D"],
	});
});

it("renders current position and count of torrents", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}, {}, {}] },
	});
	await t.expect({ pos: { cursor: 1, last: 3 } });
	await t.feed("j");
	await t.expect({ pos: { cursor: 2, last: 3 } });
});

it("renders a mark for current torrent", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}, {}, {}] },
	});
	await t.expect({ currentTorrent: 0 });
	await t.feed("j");
	await t.expect({ currentTorrent: 1 });
	await t.feed("%j");
	await t.expect({ currentTorrent: 2 });
});

it("renders torrent columns", async () => {
	const generate = (columnName, fieldName, columnCases) =>
		columnCases.map(([fieldValue, displayStr]) => [
			{ [fieldName]: fieldValue },
			{ [columnName]: displayStr },
		]);
	const cases = [
		...generate("Done", "percentDone", percentColumnCases),
		...generate("ETA", "eta", secondsColumnCases),
		...generate("Ratio", "uploadRatio", ratioColumnCases),
		...generate("Labels", "labels", [
			[["a"], "a"],
			[["a", "b", "c"], "a, b, c"],
		]),
		...generate("Size", "sizeWhenDone", sizeColumnCases),
		...generate("Check", "recheckProgress", percentColumnCases),
		[{ status: 0 }, { Status: "Paused" }],
		[{ status: 0, isFinished: true }, { Status: "Finished" }],
		[{ status: 1 }, { Status: "Check-Q" }],
		[{ status: 2 }, { Status: "Checking" }],
		[{ status: 3 }, { Status: "Queued" }],
		[{ status: 4, peersSendingToUs: 1 }, { Status: "Downloading" }],
		[{ status: 4, peersSendingToUs: 1, peersGettingFromUs: 1 }, { Status: "Downloading" }],
		[{ status: 4, peersGettingFromUs: 1 }, { Status: "Uploading" }],
		[{ status: 4 }, { Status: "Idle" }],
		[{ status: 4, isStalled: true }, { Status: "Stalled" }],
		[{ status: 5 }, { Status: "Seed-Q" }],
		[{ status: 6, peersGettingFromUs: 1 }, { Status: "Seeding" }],
		[{ status: 6 }, { Status: "Idle" }],
		[{ status: 6, isStalled: true }, { Status: "Stalled" }],
		[{ status: 7 }, { Status: "Unknown" }],
		[{ peersSendingToUs: 1 }, { "Down (peers)": "(    1)" }],
		[{ peersGettingFromUs: 1 }, { "Up (peers)": "(    1)" }],
		[{ rateDownload: 1 }, { "Down (peers)": "1B (     )" }],
		[{ rateUpload: 1 }, { "Up (peers)": "1B (     )" }],
		[{ error: 1, errorString: "rate limited" }, { Error: "Tracker warning: rate limited" }],
		[{ error: 2, errorString: "unregistered" }, { Error: "Tracker error: unregistered" }],
		[{ error: 3, errorString: "read-only filesystem" }, { Error: "Error: read-only filesystem" }],
		[{ seedRatioMode: 0, seedRatioLimit: 2 }, { "Ratio limit": "" }],
		[{ seedRatioMode: 1, seedRatioLimit: 2 }, { "Ratio limit": "2.0" }],
		[{ seedRatioMode: 2, seedRatioLimit: 2 }, { "Ratio limit": "inf" }],
		[{ uploadLimited: false, uploadLimit: 1 }, { "Up limit": "" }],
		[{ uploadLimited: true, uploadLimit: 1 }, { "Up limit": "1B" }],
		[{ downloadLimited: false, downloadLimit: 1 }, { "Down limit": "" }],
		[{ downloadLimited: true, downloadLimit: 1 }, { "Down limit": "1B" }],
	];
	const getTorrentName = (index) => `Torrent ${index.toString().padStart(3)}`;
	const t = await createTestEnvironment({
		transmission: {
			torrents: cases.map(([torrentFields], index) => ({
				...torrentFields,
				name: getTorrentName(index),
			})),
		},
		tui: {
			height: cases.length + 2,
			width: 200,
		},
	});
	await t.expect({
		torrents: cases.map(([_, torrentColumns], index) => ({
			...torrentColumns,
			Name: getTorrentName(index),
		})),
	});
});

it("renders torrent labels only when visible torrents have labels", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}, { labels: ["my label"] }, {}, {}] },
		tui: { height: 4 },
	});
	const torrentsWithLabels = (a, b) => ({
		torrents: [{ Labels: a }, { Labels: b }],
	});
	await t.expect(torrentsWithLabels("", "my label"));
	await t.feed("G");
	await t.expect(torrentsWithLabels(null, null));
});

it("periodically updates torrents", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}] },
	});
	await t.expect({ torrents: ["Torrent 1"] });
	t.torrents[0].name = "Torrent Updated";
	t.addTorrent({ name: "Torrent New" });
	await t.expectSlow({ torrents: ["Torrent New", "Torrent Updated"] });
});

it("periodically updates number of paused torrents", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}] },
	});
	await t.expect({ paused: 1 });
	t.removeTorrentById(1);
	await t.expectSlow({ paused: null });
});

it("renders files of selected torrents", async () => {
	const createTorrent = (fileName) => ({
		files: [{ name: fileName, length: 0 }],
		fileStats: [{ bytesCompleted: 0 }],
	});
	const t = await createTestEnvironment({
		transmission: {
			torrents: [createTorrent("File B"), createTorrent("File C"), createTorrent("File A")],
		},
	});
	await t.expect("Torrent");
	await t.feed("wf");
	await t.expect("File B");
	await t.feed("j");
	await t.expect("File C");
	await t.feed("j");
	await t.expect("File A");
	await t.feed("%");
	await t.expect({ files: ["File B", "File C", "File A"] });
});

it("renders file columns", async () => {
	const cases = [
		[
			{ length: 3, bytesCompleted: 1 },
			{ Done: "33.3%", Size: "3B" },
		],
		[
			{ length: GiB, bytesCompleted: GiB },
			{ Done: "100%", Size: "1.0G" },
		],
		[{}, { Priority: "" }],
		[{ priority: -1 }, { Priority: "Low" }],
		[{ priority: 0 }, { Priority: "Normal" }],
		[{ priority: 1 }, { Priority: "High" }],
		[{ wanted: true }, { Wanted: "Yes" }],
		[{ wanted: false }, { Wanted: "No" }],
	];
	const getFileName = (index) => `File ${index}`;
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{
					files: cases.map(([fields], index) => ({
						length: fields.length ?? 0,
						priority: fields.priority,
						name: getFileName(index),
					})),
					fileStats: cases.map(([fields]) => ({
						bytesCompleted: fields.bytesCompleted ?? 0,
						wanted: fields.wanted,
					})),
				},
			],
		},
	});
	await t.feed("wf");
	await t.expect({
		files: cases.map(([_, fileColumns], index) => ({ ...fileColumns, Name: getFileName(index) })),
	});
});

it("periodically updates files", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{
					files: [{ name: "File", length: 10 }],
					fileStats: [{ bytesCompleted: 0 }],
				},
			],
		},
	});
	t.feed("wf");
	await t.expect({ files: [{ Done: "" }] });
	t.torrents[0].fileStats[0].bytesCompleted = 1;
	await t.expectSlow({ files: [{ Done: "10.0%" }] });
});

it("renders peers of selected torrents", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{
					peers: [
						{
							address: "2.2.2.2",
							clientName: "Client 1",
							progress: 0.01,
							flagStr: "FLAGS1",
							rateToClient: 10 * KiB,
							rateToPeer: 0,
						},
					],
				},
				{
					peers: [
						{
							address: "10.10.10.10",
							clientName: "Client 2",
							progress: 0.5,
							flagStr: "FLAGS2",
							rateToClient: 0,
							rateToPeer: 100 * MiB,
						},
						{
							address: "2.2.2.2",
							clientName: "Client 3",
							progress: 0,
							flagStr: "",
							rateToClient: 0,
							rateToPeer: 0,
						},
					],
				},
			],
		},
	});
	await t.expect({ torrents: ["Torrent 1", "Torrent 2"] });
	await t.feed("wp");
	await t.expect({
		peers: [
			{ Address: "2.2.2.2", Flags: "FLAGS1", Done: "1.00%", Down: "10.0K", Client: "Client 1" },
		],
	});
	await t.feed("j");
	await t.expect({
		peers: [
			{ Address: "10.10.10.10", Flags: "FLAGS2", Done: "50.0%", Up: "100.0M", Client: "Client 2" },
			{ Address: "2.2.2.2", Client: "Client 3" },
		],
	});
	await t.feed("%");
	await t.expect({ peers: ["Client 2", "Client 1", "Client 3"] });
});

it("periodically updates peers", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{
					peers: [
						{
							address: "",
							clientName: "Client",
							progress: 0,
							flagStr: "",
							rateToClient: 0,
							rateToPeer: 0,
						},
					],
				},
			],
		},
	});
	t.feed("wp");
	await t.expect({ peers: [{ Done: "" }] });
	t.torrents[0].peers[0].progress = 0.1;
	await t.expectSlow({ peers: [{ Done: "10.0%" }] });
});

it("pressing C does port test", async () => {
	const t = await createTestEnvironment();

	let unblock;
	let method = t.setRPCHandler("port-test", async () => {
		await new Promise((resolve) => {
			unblock = resolve;
		});
		throw new RPCError("network unavailable");
	});
	await t.feed("C");
	await t.expect({ message: "Port: (...)" });
	unblock();
	await t.expect({ message: "Port test failed" });
	method.expectRequests(undefined);

	method = t.setRPCHandler("port-test", () => ({ "port-is-open": false }));
	await t.feed("C");
	await t.expect({ message: "Port: Closed" });
	method.expectRequests(undefined);

	method = t.setRPCHandler("port-test", () => ({ "port-is-open": true }));
	await t.feed("C");
	await t.expect({ message: "Port: Open" });
	method.expectRequests(undefined);
});

for (const [key, presentTense, pastTense, methodName] of [
	["s", "starts", "started", "torrent-start"],
	["p", "stops", "stopped", "torrent-stop"],
	["n", "reannounces", "reannounced", "torrent-reannounce"],
]) {
	it(`pressing ${key} ${presentTense} selected torrents`, async () => {
		const t = await createTestEnvironment({
			transmission: { torrents: [{}, {}] },
		});

		const method = t.setRPCHandler(methodName, () => {});

		await t.feed(key);
		await t.expect({ message: `1 torrent ${pastTense}` });
		method.expectRequests({ ids: [t.getTorrentHash(1)] });

		await t.feed(`%${key}`);
		await t.expect({ message: `2 torrents ${pastTense}` });
		method.expectRequests({ ids: [t.getTorrentHash(1), t.getTorrentHash(2)] });
	});
}

for (const [key, presentTense, pastTense, methodName] of [
	["S", "starts", "started", "torrent-start"],
	["P", "stops", "stopped", "torrent-stop"],
	["N", "reannounces", "reannounced", "torrent-reannounce"],
]) {
	it(`pressing ${key} ${presentTense} all torrents`, async () => {
		const t = await createTestEnvironment();
		const method = t.setRPCHandler(methodName, () => {});
		await t.feed(key);
		await t.expect({ message: `All torrents ${pastTense}` });
		method.expectRequests(undefined);
	});
}

it("pressing u allows changing torrent queue", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{ queuePosition: 20, name: "Middle" },
				{ queuePosition: 500, name: "Lowest" },
				{ queuePosition: 1, name: "Highest" },
			],
		},
	});

	const method = t.setRPCHandler("torrent-set", () => {});

	await t.feed("u");
	await t.expect("# Re-queue torrents");
	await t.feed("dd", ":w", "Enter", ":cq", "Enter");
	await t.expect({ message: "Aborted, no torrents re-queued" });

	await t.feed("u");
	await t.expect(/Highest.*Middle.*Lowest/s);
	await t.feed("dd", "ZZ");
	await t.expect({ message: "2 torrents re-queued" });
	method.expectRequests(
		{ queuePosition: 0, ids: t.getTorrentHash(1) },
		{ queuePosition: 1, ids: t.getTorrentHash(2) },
	);
});

it("pressing / opens torrent finder", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}, {}, {}, {}] },
	});

	await t.feed("/");
	await t.expect(">");
	await t.feed("^Torr 4", "Enter");
	await t.expect({
		torrents: ["Torrent 1", "Torrent 2", "Torrent 3", "Torrent 4"],
		pos: { cursor: 4, last: 4 },
	});

	await t.feed("/");
	await t.expect(">");
	await t.feed("1|3", "M-Enter");
	await t.expect({
		pos: { cursor: 2, last: 2, total: 4 },
		torrents: ["Torrent 1", "Torrent 3"],
	});

	await t.feed("/");
	await t.expect(">");
	await t.feed("C-C");
	await t.expect({
		pos: { cursor: 2, last: 2, total: 4 },
		message: "fzr exited non-zero",
	});
});

it("pressing e allows narrowing torrent list", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}, {}, {}, {}] },
	});

	await t.feed("e");
	await t.expect(["# Filter torrents", "Done", "Paused"]);
	await t.feed(":g/Torrent [13]/d", "Enter", "ZZ");
	await t.expect({
		message: "2 torrents filtered",
		pos: { cursor: 1, last: 2, total: 4 },
		torrents: ["Torrent 2", "Torrent 4"],
	});

	await t.feed("e");
	await t.expect("# Filter torrents");
	await t.feed("dG", ":w", "Enter", ":cq", "Enter");
	await t.expect({
		message: "Aborted, no torrents filtered",
		pos: { cursor: 1, last: 2, total: 4 },
		torrents: ["Torrent 2", "Torrent 4"],
	});

	await t.feed("e");
	await t.expect("# Filter torrents");
	await t.feed(":g/^1.*Torrent 2/d", "Enter", "ZZ");
	await t.expect({
		message: "1 torrent filtered",
		pos: { cursor: 1, last: 1, total: 4 },
		torrents: ["Torrent 4"],
	});

	await t.feed("e");
	await t.expect("# Filter torrents");
	await t.feed("dG", "ZZ");
	await t.expect({
		message: "Filter reset",
		pos: { cursor: 1, last: 4 },
		torrents: ["Torrent 1", "Torrent 2", "Torrent 3", "Torrent 4"],
	});
});

for (const [key, withData] of [
	["d", false],
	["D", true],
	// FIXME: Fix $TERM or something.
	// ['Delete', false],
	// ['S-Delete', true],
]) {
	it(`pressing ${key} allows removing torrent${withData ? " with local data delete" : ""}`, async () => {
		const t = await createTestEnvironment({
			transmission: { torrents: [{}, {}, {}, {}] },
		});

		const method = t.setRPCHandler("torrent-remove", () => {});

		await t.feed(key);
		await t.expect("# Remove torrents");
		await t.feed("ZZ");
		await t.expect({ message: "No torrents removed" });

		await t.feed(key);
		await t.expect("# Remove torrents");
		await t.feed(...vimUncommentAll, ":w", "Enter", ":cq", "Enter");
		await t.expect({ message: "Aborted, no torrents removed" });

		await t.feed(key);
		await t.expect([
			"# Remove torrents",
			withData
				? /# Local data will be PERMANENTLY DELETED.*Torrent 1.*PERMANENTLY DELETED/s
				: /Torrent 1.*Local data will be kept/s,
		]);
		const removeTorrent1 = {
			ids: [t.getTorrentHash(1)],
			"delete-local-data": withData,
		};
		t.removeTorrentById(1);
		await t.feed(...vimUncommentAll, "ZZ");
		await t.expect({
			message: `1 torrent removed${withData ? " and local data deleted" : ""}`,
		});
		method.expectRequests(removeTorrent1);

		await t.feed(`%${key}`);
		await t.expect(["# Remove torrents", "Torrent 3"]);
		const removeTorrent24 = {
			ids: [t.getTorrentHash(2), t.getTorrentHash(4)],
			"delete-local-data": withData,
		};
		t.removeTorrentById(2);
		t.removeTorrentById(4);
		await t.feed(":g/Torrent [24]/s/# //", "Enter", "ZZ");
		await t.expect({
			message: `2 torrents removed${withData ? " and local data deleted" : ""}`,
		});
		await t.feed("r");
		await t.expect({
			pos: { cursor: 1, last: 1 },
			torrents: ["Torrent 3"],
		});
		method.expectRequests(removeTorrent24);
	});
}

it("pressing c allows verifying torrent data", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}, {}, {}] },
	});

	const method = t.setRPCHandler("torrent-verify", () => {});

	await t.feed("c");
	await t.expect("# Check torrents");
	await t.feed(":cq", "Enter");
	await t.expect({ message: "Aborted, no torrents checked" });

	await t.feed("c");
	await t.expect(["# Check torrents", "Torrent 1"]);
	await t.feed("ZZ");
	await t.expect({ message: "1 torrent started checking" });
	method.expectRequests({ ids: [t.getTorrentHash(1)] });

	await t.feed("%c");
	await t.expect("# Check torrents");
	await t.feed(":g/Torrent 1/d", "Enter", "ZZ");
	await t.expect({ message: "2 torrents started checking" });
	method.expectRequests({ ids: [t.getTorrentHash(2), t.getTorrentHash(3)] });
});

it("pressing f allows selecting torrent files", async () => {
	const createTorrent = (...files) => ({
		files: files.map(([name]) => ({ name, length: 0 })),
		fileStats: files.map(([_, wanted]) => ({ wanted, bytesCompleted: 0 })),
	});
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				createTorrent(["File B", false], ["File C", true], ["File A", false]),
				createTorrent(["File Z", true], ["File Y", false], ["File X", true]),
				createTorrent(["File Third Wanted", true], ["File Third Not Wanted", false]),
			],
		},
		tui: {
			height: 25,
		},
	});

	const method = t.setRPCHandler("torrent-set", () => {});

	await t.feed("%f");
	await t.expect("# Select torrent files");
	await t.feed("ZZ");
	await t.expect({ message: "No torrents changed" });

	await t.feed("f");
	await t.expect("# Select torrent files");
	await t.feed(...vimUncommentAll, ":w", "Enter", ":cq", "Enter");
	await t.expect({ message: "Aborted, no torrents changed" });

	await t.feed("f");
	await t.expect([
		/Torrent 1\n.*1\/3 files selected/,
		/Torrent 2\n.*2\/3 files selected/,
		/Torrent 3\n.*1\/2 files selected/,
	]);
	await t.feed(
		...[":g/File B/s/# //", "Enter"],
		...[":g/File C/d", "Enter"],
		...[":g/File Z/s/^/#/", "Enter"],
		...[":g/File Y/s/# //", "Enter"],
		...[":g/File Third/dd", "Enter"],
		"ZZ",
	);
	await t.expect({ message: "2 torrents changed" });
	method.expectRequests(
		{
			ids: t.getTorrentHash(1),
			"files-unwanted": [1],
			"files-wanted": [0],
		},
		{
			ids: t.getTorrentHash(2),
			"files-unwanted": [0],
			"files-wanted": [1],
		},
	);
});

for (const [key, filesCommented, filesDeleted] of [
	["a", true, false],
	["A", false, true],
]) {
	it(`pressing ${key} allows adding torrents ${filesDeleted ? "with file delete" : ""}`, async () => {
		const t = await createTestEnvironment({
			transmission: { torrents: [{}, {}] },
		});
		await t.shell(
			[
				"mkdir -p /cwd/path/to",
				"echo torrent file content > '/cwd/addMe $PATH $(echo *) '\"'\"'`\".torrent'",
				"echo some content > /cwd/keepMe.torrent",
				"touch /cwd/invalid1.torrent",
				"touch /cwd/invalid2.torrent",
				"echo some content > /cwd/notAtorrent",
				"yes | head -n 1000 > /cwd/path/to/addMeToo.torrent",
			].join("\n"),
		);

		let invalidCounter = 0;
		const method = t.setRPCHandler("torrent-add", (args) => {
			assert.ok(Boolean("metainfo" in args) !== Boolean("filename" in args));
			if (args.metainfo === "") {
				throw new RPCError(`invalid torrent ${++invalidCounter}`);
			}
			if (args.filename === "http://first-torrent-duplicated") {
				return { "torrent-duplicate": { hashString: t.getTorrentHash(1) } };
			}
			if (args.filename === "http://second-torrent-duplicated") {
				return { "torrent-duplicate": { hashString: t.getTorrentHash(2) } };
			}
			return { "torrent-added": { hashString: t.addTorrent({}).hashString } };
		});

		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed(":cq", "Enter");
		await t.expect({ message: "Aborted, no torrents added" });

		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed("dG", "ZZ");
		await t.expect({ message: "No torrents added" });

		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed("cG", "http://new-torrent", "Escape", "ZZ");
		await t.expect({
			message: "1 torrent added",
			pos: { cursor: 3, last: 3 },
			paused: 3,
			torrents: ["Torrent 1", "Torrent 2", "Torrent 3"],
		});
		method.expectRequests({ filename: "http://new-torrent", paused: true });

		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed("cG", "http://first-torrent-duplicated", "Escape", "ZZ");
		await t.expect({ message: "1 torrent added", pos: { cursor: 1, last: 3 } });
		method.expectRequests({ filename: "http://first-torrent-duplicated", paused: true });

		await t.feed(key);
		await t.expect([
			"# Add torrents",
			filesDeleted ? "Local files PERMANENTLY DELETED" : "",
			"keepMe",
		]);
		await t.feed(
			"i",
			"http://first-torrent-duplicated",
			"Enter",
			"https://torrent.site/my.torrent",
			"Escape",
			...(filesCommented ? [":g/addMe\\|invalid/s/# //", "Enter"] : []),
			...(filesCommented ? [] : [":g/keepMe/s/^/# /", "Enter"]),
			"ZZ",
		);
		await t.expect([
			/Error: invalid torrent 1\n.*invalid1.torrent/,
			/Error: invalid torrent 2\n.*invalid2.torrent/,
		]);
		method.expectRequests(
			{ filename: "http://first-torrent-duplicated", paused: true },
			{ filename: "https://torrent.site/my.torrent", paused: true },
			{ metainfo: Buffer.from("torrent file content\n").toString("base64"), paused: true },
			{ metainfo: "", paused: true },
			{ metainfo: "", paused: true },
		);
		await t.feed("I", "path/to/addMeToo.torrent", "Enter", "Escape", "ZZ");
		await t.expect([
			/Error: invalid torrent 3\n.*invalid1.torrent/,
			/Error: invalid torrent 4\n.*invalid2.torrent/,
		]);
		method.expectRequests(
			{ metainfo: Buffer.from("y\n".repeat(1000)).toString("base64"), paused: true },
			{ metainfo: "", paused: true },
			{ metainfo: "", paused: true },
		);
		await t.feed("cG", "http://dont-add-me", "Escape", ":w", "Enter", ":cq", "Enter");
		await t.expect({
			message: "4 torrents added",
			pos: { cursor: 1, last: 4, total: 6 },
			paused: 6,
			torrents: ["Torrent 1", "Torrent 4", "Torrent 5", "Torrent 6"],
		});

		await t.feed("G");
		await t.expect({ pos: { cursor: 4, last: 4, total: 6 } });
		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed("cG", "http://first-torrent-duplicated", "Escape", "ZZ");
		await t.expect({ message: "1 torrent added", pos: { cursor: 1, last: 4, total: 6 } });
		method.expectRequests({ filename: "http://first-torrent-duplicated", paused: true });

		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed("cG", "http://second-torrent-duplicated", "Escape", "ZZ");
		await t.expect({
			message: "1 torrent added",
			pos: { cursor: 1, last: 1, total: 6 },
			torrents: ["Torrent 2"],
		});
		method.expectRequests({ filename: "http://second-torrent-duplicated", paused: true });

		await t.feed(key);
		await t.expect("# Add torrents");
		await t.feed("cG", "http://new2-torrent", "Escape", "ZZ");
		await t.expect({
			message: "1 torrent added",
			pos: { cursor: 1, last: 1, total: 7 },
			paused: 7,
		});
		method.expectRequests({ filename: "http://new2-torrent", paused: true });

		await t.shell(`${filesDeleted ? "! " : ""}test -f /cwd/path/to/addMeToo.torrent`);
		await t.shell("test -f /cwd/keepMe.torrent");
		await t.shell("test -f /cwd/invalid1.torrent");
	});
}

it("pressing m allows moving torrents", async () => {
	const t = await createTestEnvironment({
		transmission: {
			torrents: [
				{ downloadDir: "location C" },
				{ downloadDir: "location A" },
				{ downloadDir: "location B" },
				{ downloadDir: "location A" },
				{ downloadDir: "location D\r\n\t\\" },
			],
		},
		tui: {
			height: 30,
		},
	});

	const method = t.setRPCHandler("torrent-set-location", () => {});

	await t.feed("%m");
	await t.expect("# Set torrent location");
	await t.feed(":cq", "Enter");
	await t.expect({ message: "Aborted, no torrents moved" });

	await t.feed("m");
	await t.expect("# Set torrent location");
	await t.feed("ZZ");
	await t.expect({ message: "No torrents moved" });

	await t.feed("m");
	await t.expect("# Set torrent location");
	await t.feed(":g/location/d", "Enter", "ZZ");
	await t.expect({ message: "No torrents moved" });

	await t.feed("m");
	await t.expect([
		"# Set torrent location",
		/Default location.*\/session\/download\/dir.*Current location.*\/cwd/s,
	]);
	await t.feed(
		...[":g/Torrent 1/move /location A/-1", "Enter"],
		...[":g/Torrent 2/d", "Enter"],
		...[":g/Torrent 3/move /location A/-1", "Enter"],
		...[":%s/location D/location E/", "Enter"],
		"ZZ",
	);
	await t.expect({ message: "3 torrents moved" });
	method.expectRequests(
		{
			ids: [t.getTorrentHash(1), t.getTorrentHash(3)],
			location: "location A",
			move: true,
		},
		{
			ids: [t.getTorrentHash(5)],
			location: "location E\r\n\t\\",
			move: true,
		},
	);
});

it("pressing la enables alternate speed limit", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}] },
	});
	t.sessionStats["current-stats"].downloadedBytes = 5;
	const method = t.setRPCHandler("session-set", () => {
		t.sessionInfo["alt-speed-enabled"] = true;
		t.sessionInfo["alt-speed-down"] = 1;
	});
	await t.expect({ torrents: ["Torrent 1"] });
	await t.feed("la");
	await t.expect({
		message: "Alternate speed limit enabled",
		down: { speed: "", speedLimit: "1000B", session: "5B" },
	});
	method.expectRequests({ "alt-speed-enabled": true });
});

it("pressing lu disables alternate speed limit", async () => {
	const t = await createTestEnvironment();
	t.sessionInfo["alt-speed-enabled"] = true;
	t.sessionInfo["alt-speed-down"] = 1;
	t.sessionStats["current-stats"].downloadedBytes = 5;
	await t.expect({
		down: { speed: "", speedLimit: "1000B", session: "5B" },
	});
	const method = t.setRPCHandler("session-set", () => {
		t.sessionInfo["alt-speed-enabled"] = false;
		t.sessionInfo["speed-limit-down-enabled"] = true;
		t.sessionInfo["speed-limit-down"] = 2;
	});
	await t.feed("lu");
	await t.expect({
		message: "Alternate speed limit disabled",
		down: { speed: "", speedLimit: "2.0K", session: "5B" },
	});
	method.expectRequests({ "alt-speed-enabled": false });
});

it("pressing q when there's no open window, closes application", async () => {
	const t = await createTestEnvironment();
	await t.feed("q");
	await t.expect("[exited 0]");
});

it("pressing q when there's an open window, closes it", async () => {
	const checkWindow = async (openWith, text) => {
		await t.feed(openWith);
		await t.expect(text);
		await t.feed("q");
	};
	const t = await createTestEnvironment();
	await checkWindow("wf", "Wanted");
	await checkWindow("wp", "Client");
	await checkWindow("wt", "Tier");
	await t.feed("q");
	await t.expect("[exited 0]");
});

it("pressing ? opens manual", async () => {
	const t = await createTestEnvironment({
		transmission: { torrents: [{}] },
	});
	await t.feed("?");
	await t.expect(["TRANSMISSION-TUI(1)", "NAME", "SYNOPSIS", "DESCRIPTION"]);
	await t.feed("q");
	await t.expect({ torrents: ["Torrent 1"] });
});

it("pressing QQ closes session", async () => {
	const t = await createTestEnvironment();
	const method = t.setRPCHandler("session-close", () => {});
	await t.feed("QQ");
	await t.expect("[exited 0]");
	method.expectRequests(undefined);
});
