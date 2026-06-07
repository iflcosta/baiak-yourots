#pragma once

#include <framework/graphics/declarations.h>
#include <framework/core/inputevent.h>
#include <string>
#include <unordered_map>
#include <vector>

class Painter;

class UltraLightManager
{
public:
    UltraLightManager() = default;
    ~UltraLightManager() = default;
    UltraLightManager(const UltraLightManager&) = delete;
    UltraLightManager& operator=(const UltraLightManager&) = delete;

    static UltraLightManager& instance();

    bool initialize();
    void update();
    void render(Painter& painter);
    void shutdown();
    bool isInitialized() { return m_initialized; }

    bool createView(const std::string& name, int width, int height, const std::string& htmlPath);
    void removeView(const std::string& name);
    void setViewVisible(const std::string& name, bool visible);
    void setViewPosition(const std::string& name, int x, int y);
    void setViewFocus(const std::string& name, bool focused);
    bool hasView(const std::string& name);
    bool isViewVisible(const std::string& name);
    void loadFile(const std::string& name, const std::string& htmlPath);

    void callJSFunction(const std::string& viewName, const std::string& functionName, const std::string& argsJson);
    std::string getItemSpriteDataUri(uint16 itemId);

    bool handleInputEvent(const InputEvent& event);
    void dispatchLuaFunction(const std::string& functionPath, const std::vector<std::string>& args);

private:
    struct ViewData {
        void* view = nullptr;
        int x = 0, y = 0;
        bool visible = true;
        bool focused = false;
        TexturePtr texture;
    };

    std::string detectUltralightBaseDir();

    bool m_initialized = false;
    std::unordered_map<std::string, ViewData> m_views;
};

extern UltraLightManager g_ultralightManager;
