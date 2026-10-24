#pragma once

// Lingmo Intents of the file manager (files.reveal, files.open, files.search)
// on com.lingmo.FileManager.Intents /Intents. `lingmo-filemanager --intents`
// (D-Bus activation) serves them from a small process without windows; the
// windows themselves are opened by running lingmo-filemanager as usual.
// Kept apart from application.cpp on purpose: the only hook is in main.cpp.
namespace FilesIntents {
bool requested(int argc, char *argv[]);
int run(int argc, char *argv[]);
}
