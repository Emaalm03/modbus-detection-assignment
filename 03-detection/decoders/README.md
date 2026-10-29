# Decoders

No custom decoder was written. Wazuh's built-in `json` decoder
auto-extracts every field from Zeek's modbus.log and conn.log lines
(func, id.orig_h, pdu_type, orig_pkts, etc.) directly, since both are
single-line JSON. This was confirmed with wazuh-logtest: every log
line decodes as `name: 'json'` with all fields readable, with no
regex/decoder needed.

A small optional parent decoder (tagging lines as zeek-modbus-pdu or
zeek-conn) was attempted but caused a manager outage due to a
malformed leftover fragment and was removed. Given the JSON decoder
already provides full field extraction, it was not reinstated.

The real "decoding" work for this assignment happened upstream, in
how Zeek was configured to structure its output, and in a Filebeat
field-mapping fix (data.id -> data-conn.id) needed to resolve an
index-mapping conflict between modbus.log's flat fields and
conn.log's nested structure.
