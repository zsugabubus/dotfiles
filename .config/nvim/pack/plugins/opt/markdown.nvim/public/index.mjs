// https://docs.github.com/en/get-started/writing-on-github
import { marked } from "https://cdn.jsdelivr.net/npm/marked@15.0.3/+esm";

const defaultBackground = "light";

const alertRe = /^\[!([a-zA-Z]+)\]\s*\n(.*)/;
const colorRe = /^(#[a-zA-Z0-9]+|[a-z0-9]+\([a-z0-9.,% ]+\))$/;
const emojiRe = /:([a-z0-9_+-]+):/g;
const punctationsRe = /[^a-z0-9 ]/g;
const spacesRe = / +/g;
const videoRe = /\.mp4$/;

const getIcon = (iconName) =>
	`<svg width="16" height="16"><use href="/.index.svg#${iconName}"/></svg>`;

const linkIcon = getIcon("link");
const cameraVideoIcon = getIcon("camera-video");

const alerts = new Map([
	["note", ["markdown-alert-note", getIcon("info"), "Note"]],
	["tip", ["markdown-alert-tip", getIcon("light-bulb"), "Tip"]],
	["important", ["markdown-alert-important", getIcon("report"), "Important"]],
	["warning", ["markdown-alert-warning", getIcon("warning"), "Warning"]],
	["caution", ["markdown-alert-caution", getIcon("stop"), "Caution"]],
]);

const textarea = document.createElement("textarea");
const escapeHtml = (raw) => {
	textarea.textContent = raw;
	return textarea.innerHTML;
};

const setBackground = (value) => {
	sessionStorage.setItem("background", value);
	document.body.dataset.background = value;
};

const getHeaderName = (headerText) =>
	headerText
		.toLowerCase()
		.replace(punctationsRe, "")
		.trim()
		.replace(spacesRe, "-");

const countTokenLines = (token) => token.raw.split("\n").length - 1;

setBackground(sessionStorage.getItem("background") ?? defaultBackground);

const emojis = new Map(
	Object.entries(
		await (await fetch("https://api.github.com/emojis")).json(),
	).map(([name, url]) => [
		name,
		`<img class="emoji" src="${url}" loading="lazy">`,
	]),
);
const emojiReplacer = (original, name) => emojis.get(name) ?? original;

marked.use({
	gfm: true,
	breaks: false,
	extensions: [
		{
			name: "line",
			renderer({ line }) {
				return `<div data-line=${line}></div>`;
			},
		},
		{
			name: "video",
			renderer({ link }) {
				const summary = `<summary>${cameraVideoIcon}Video</summary>`;
				const video = `<video src="${link}" controls="controls" preload="none"></video>`;
				return `<details class="markdown-video" open>${summary}${video}</details>`;
			},
		},
		{
			name: "image",
			renderer({ href, title, text }) {
				return `<img src="${href}" loading="lazy" alt="${escapeHtml(text)}" title="${escapeHtml(title || "")}">`;
			},
		},
	],
	renderer: {
		heading({ tokens, depth }) {
			const content = this.parser.parseInline(tokens);
			const textContent = this.parser.parseInline(
				tokens,
				this.parser.textRenderer,
			);
			const name = getHeaderName(textContent);
			return `<h${depth}><a name="${name}" class="anchor" href="#${name}">${linkIcon}</a>${content}</h${depth}>`;
		},
		codespan({ text }) {
			const extra = colorRe.test(text)
				? `<span style="background-color:${text}" class="color"></span>`
				: "";
			return `<code>${escapeHtml(text)}${extra}</code>`;
		},
		blockquote({ tokens }) {
			if (
				tokens[0].type === "paragraph" &&
				tokens[0].tokens[0].type === "text"
			) {
				const textToken = tokens[0].tokens[0];
				const m = textToken.text.match(alertRe);
				if (m) {
					const name = m[1].toLowerCase();
					const rest = m[2];
					if (alerts.has(name)) {
						const [className, icon, title] = alerts.get(name);
						textToken.text = rest;
						const content = this.parser.parse(tokens);
						return `<div class="markdown-alert ${className}"><p class="title">${icon}${title}</p>${content}</div>`;
					}
				}
			}
			return `<blockquote>${this.parser.parse(tokens)}</blockquote>`;
		},
		text({ tokens, text, escaped }) {
			if (tokens) {
				return this.parser.parseInline(tokens);
			}
			return (escaped ? text : escapeHtml(text)).replace(
				emojiRe,
				emojiReplacer,
			);
		},
	},
});

const markdownContentEl = document.getElementById("markdown-content");

let cursor = 0;
let lineMap = null;
let cursorOff = false;

const scrollToCursor = () => scrollToLine(cursor);

const scrollToLine = (line) => {
	if (!lineMap) {
		lineMap = [];
		for (const el of markdownContentEl.querySelectorAll("[data-line]")) {
			lineMap[+el.dataset.line] ??= el;
		}
	}

	cursorOff = false;

	let lineAbove = line;
	if (lineAbove < 1) {
		lineAbove = 1;
		cursorOff = true;
	} else {
		while (!lineMap[lineAbove]) {
			lineAbove--;
		}
	}

	let lineBelow = line;
	if (lineBelow >= lineMap.length) {
		lineBelow = lineMap.length - 1;
		cursorOff = true;
	} else {
		while (!lineMap[lineBelow]) {
			lineBelow++;
		}
	}

	const aboveEl = lineMap[lineAbove];
	const belowEl = lineMap[lineBelow];

	const aboveY = aboveEl.getBoundingClientRect().top;
	const belowY = belowEl.getBoundingClientRect().top;

	const percent = (line - lineAbove + 1) / (lineBelow - lineAbove + 1);
	const y = aboveY + (belowY - aboveY) * percent;
	const height = window.innerHeight;

	if (y >= height * 0.25 && y <= height * 0.75) {
		return;
	}

	window.scrollTo(0, window.scrollY + y - height / 3);
};

let mermaidCache = new Map();
let isMermaidInitialized = false;

const expandMermaid = async (el) => {
	const { default: mermaid } = await import(
		"https://cdn.jsdelivr.net/npm/mermaid@11.4.1/+esm"
	);

	if (!isMermaidInitialized) {
		isMermaidInitialized = true;
		mermaid.initialize();
	}

	const oldHtml = el.outerHTML;
	await mermaid.run({ nodes: [el] });
	const newHtml = el.outerHTML;

	mermaidCache.set(oldHtml, newHtml);
};

const mermaidObserver = new IntersectionObserver((entries) => {
	for (const entry of entries) {
		if (entry.intersectionRatio > 0) {
			mermaidObserver.unobserve(entry.target);
			expandMermaid(entry.target);
		}
	}
});

let languageCache = new Map();
const seenLanguages = new Set();

const highlightCode = async (el) => {
	const { default: hljs } = await import(
		"https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/es/highlight.min.js"
	);

	const languageName = el.className.match(/language-([^ ]+)/)?.[1];

	if (languageName && !seenLanguages.has(languageName)) {
		seenLanguages.add(languageName);
		const { default: languageDefinition } = await import(
			`https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/es/languages/${languageName}.min.js`
		);
		hljs.registerLanguage(languageName, languageDefinition);
	}

	const oldHtml = el.outerHTML;
	hljs.highlightElement(el);
	const newHtml = el.outerHTML;

	languageCache.set(oldHtml, newHtml);
};

const languageObserver = new IntersectionObserver((entries) => {
	for (const entry of entries) {
		if (entry.intersectionRatio > 0) {
			languageObserver.unobserve(entry.target);
			highlightCode(entry.target);
		}
	}
});

let pendingSource = null;

document.addEventListener("visibilitychange", () => {
	if (!document.hidden && pendingSource) {
		setMarkdown(pendingSource);
		pendingSource = null;
	}
});

const setMarkdown = (source) => {
	if (document.hidden) {
		pendingSource = source;
		return;
	}

	const tokens = marked.lexer(source);

	let line = 1;

	const tokensWithLines = tokens.flatMap((token) => {
		const lineToken = { type: "line", line };

		if (token.type === "list") {
			let i = line;
			for (const item of token.items) {
				let j = i;
				item.tokens = item.tokens.flatMap((token) => {
					const lineToken = { type: "line", line: j };
					j += countTokenLines(token);
					return [lineToken, token];
				});
				i += countTokenLines(item);
			}
		}

		line += countTokenLines(token);

		if (
			token.type === "paragraph" &&
			token.tokens.length === 1 &&
			token.tokens[0].type === "link"
		) {
			try {
				const url = new URL(token.tokens[0].text);
				if (videoRe.test(url.pathname)) {
					token = {
						type: "video",
						link: token.tokens[0].text,
					};
				}
			} catch (_) {}
		}

		return [lineToken, token];
	});

	tokensWithLines.push({ type: "line", line });

	const html = marked.parser(tokensWithLines);

	lineMap = null;
	mermaidObserver.disconnect();
	languageObserver.disconnect();
	markdownContentEl.innerHTML = html;

	const newMermaidCache = new Map();

	for (const el of document.querySelectorAll(".language-mermaid")) {
		const elHtml = el.outerHTML;
		const newHtml = mermaidCache.get(elHtml);
		if (newHtml) {
			el.outerHTML = newHtml;
			newMermaidCache.set(elHtml, newHtml);
		} else {
			mermaidObserver.observe(el);
		}
	}

	mermaidCache = newMermaidCache;

	const newLanguageCache = new Map();

	for (const el of document.querySelectorAll("[class^=language-]")) {
		const elHtml = el.outerHTML;
		const newHtml = languageCache.get(elHtml);
		if (newHtml) {
			el.outerHTML = newHtml;
			newLanguageCache.set(elHtml, newHtml);
		} else {
			languageObserver.observe(el);
		}
	}

	languageCache = newLanguageCache;

	if (cursorOff) {
		scrollToCursor();
	}
};

const events = new EventSource("/events");

events.addEventListener("open", () => {
	document.title = "NVIM";
	setMarkdown("❤️ Connected to `nvim`. 🤖 `:e awesome.md`");
});

events.addEventListener("error", () => {
	document.title = "NVIM";
	setMarkdown("💔 Disconnected from `nvim`. 📡 Trying to reconnect.");
});

events.addEventListener("file-change", (e) => {
	document.title = `${JSON.parse(e.data)} - NVIM`;
});

let textChangeTimeout;

events.addEventListener("text-change", (e) => {
	if (textChangeTimeout) {
		clearTimeout(textChangeTimeout);
	}

	textChangeTimeout = setTimeout(() => {
		setMarkdown(JSON.parse(e.data));
	}, 0);
});

events.addEventListener("cursor-move", (e) => {
	cursor = JSON.parse(e.data);
	scrollToCursor();
});

events.addEventListener("background-change", (e) => {
	setBackground(JSON.parse(e.data));
});
