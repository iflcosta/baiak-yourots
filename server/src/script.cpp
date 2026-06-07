// Copyright 2023 The Forgotten Server Authors. All rights reserved.
// Use of this source code is governed by the GPL-2.0 License that can be found in the LICENSE file.

#include "otpch.h"

#include "script.h"

#include "configmanager.h"

#include <fmt/color.h>
#include <fmt/ranges.h>
#include "logger.h"

extern LuaEnvironment g_luaEnvironment;

Scripts::Scripts() : scriptInterface("Scripts Interface") { scriptInterface.initState(); }

Scripts::~Scripts() { scriptInterface.reInitState(); }

bool Scripts::loadScripts(const std::string& folderName, bool isLib, bool reload)
{
	namespace fs = std::filesystem;

	const auto dir = fs::current_path() / "data" / folderName;
	if (!fs::exists(dir) || !fs::is_directory(dir)) {
		LOG_WARN(fmt::format("[Warning - Scripts::loadScripts] Can not load folder '{}'.", folderName));
		return false;
	}

	bool scriptsConsoleLogs = getBoolean(ConfigManager::SCRIPTS_CONSOLE_LOGS);
	std::vector<std::string> disabled = {}, loaded = {}, reloaded = {};

	fs::recursive_directory_iterator endit;
	std::vector<std::pair<fs::path, std::string>> v;
	static constexpr std::string_view disable = "#";
	for (fs::recursive_directory_iterator it(dir); it != endit; ++it) {
		auto fn = it->path().parent_path().filename();
		if ((fn == "lib" && !isLib) || fn == "events") {
			continue;
		}
		if (fs::is_regular_file(*it) && it->path().extension() == ".lua") {
			size_t found = it->path().filename().string().find(disable);
			if (found != std::string::npos) {
				if (scriptsConsoleLogs) {
					const auto& scrName = it->path().filename().string();
					disabled.push_back(
					    fmt::format("\"{}\"", fmt::format(fg(fmt::color::yellow), "{}",
					                                      std::string_view(scrName.data(), scrName.size() - 4))));
				}
				continue;
			}
			std::string canonical = fs::canonical(it->path()).string();
			if (!loadedFiles.contains(canonical)) {
				v.emplace_back(it->path(), std::move(canonical));
			}
		}
	}
	sort(v.begin(), v.end(), [](const auto& a, const auto& b) { return a.first < b.first; });
	for (auto& [path, canonical] : v) {
		const std::string scriptFile = path.string();
		if (scriptInterface.loadFile(scriptFile) == -1) {
			LOG_ERROR(fmt::format("> {} [error]", path.filename().string()));
			LOG_ERROR(fmt::format("^ {}", scriptInterface.getLastLuaError()));
			continue;
		}

		loadedFiles.insert(std::move(canonical));

		if (scriptsConsoleLogs) {
			const auto& scrName = path.filename().string();
			if (!reload) {
				loaded.push_back(fmt::format(
				    "\"{}\"",
				    fmt::format(fg(fmt::color::green), "{}", std::string_view(scrName.data(), scrName.size() - 4))));
			} else {
				reloaded.push_back(fmt::format(
				    "\"{}\"",
				    fmt::format(fg(fmt::color::green), "{}", std::string_view(scrName.data(), scrName.size() - 4))));
			}
		}
	}

	if (scriptsConsoleLogs) {
		if (!disabled.empty()) {
			LOG_INFO(fmt::format("{{{}}}", fmt::join(disabled, ", ")));
		}

		if (!loaded.empty()) {
			LOG_INFO(fmt::format("{{{}}}", fmt::join(loaded, ", ")));
		}

		if (!reloaded.empty()) {
			LOG_INFO(fmt::format("{{{}}}", fmt::join(reloaded, ", ")));
		}
	}

	return true;
}
