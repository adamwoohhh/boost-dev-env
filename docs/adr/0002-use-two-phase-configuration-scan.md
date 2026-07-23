# Use a two-phase configuration scan

Configuration discovery uses a shallow scan first, collecting paths, file types, sizes, and likely software ownership without reading configuration contents. File contents are read only after the user accepts a Configuration Candidate for deeper inspection, reducing accidental exposure of secrets, internal endpoints, and personal data during capture.
