class_name SaveCodec
extends RefCounted
## Envelope: {"format":1, "checksum": sha256(payload), "payload": "<json>"}.
## The checksum detects truncation/corruption, it is NOT tamper protection:
## anything on the client can be edited. Competitive economy needs a server.

const FORMAT := 1


static func encode(data: Dictionary) -> String:
	var payload := JSON.stringify(data)
	return JSON.stringify({"format": FORMAT, "checksum": payload.sha256_text(), "payload": payload})


## Returns {"ok": bool, "data": Dictionary, "error": String}.
static func decode(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"ok": false, "data": {}, "error": "empty"}
	var env: Variant = JSON.parse_string(text)
	if not env is Dictionary or not env.has("payload") or not env.has("checksum"):
		return {"ok": false, "data": {}, "error": "envelope"}
	var payload: String = str(env["payload"])
	if payload.sha256_text() != str(env["checksum"]):
		return {"ok": false, "data": {}, "error": "checksum"}
	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary:
		return {"ok": false, "data": {}, "error": "payload"}
	return {"ok": true, "data": data, "error": ""}
