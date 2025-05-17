import { spec } from "node:test/reporters";
import { compose } from "node:stream";

async function* hidePassedLogs(source) {
	let logs = [];
	for await (const event of source) {
		if (event.type === "test:stderr" || event.type === "test:stdout") {
			logs.push(event);
			continue;
		} else if (event.type === "test:pass") {
			logs = [];
		} else if (event.type === "test:fail") {
			yield* logs;
			logs = [];
		}
		yield event;
	}
	// WTF: Don't allow stream to be destroyed otherwise we get a nice error message.
	await new Promise(() => {});
}

export default compose(hidePassedLogs, spec);
