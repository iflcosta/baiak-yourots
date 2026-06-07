#include "ultralightmanager.h"

#include <framework/core/application.h>
#include <framework/core/eventdispatcher.h>
#include <framework/graphics/graphics.h>
#include <framework/graphics/image.h>
#include <framework/graphics/painter.h>
#include <framework/graphics/texture.h>
#include <framework/luaengine/luainterface.h>
#include <framework/platform/platform.h>
#include <framework/stdext/string.h>

#ifdef OTCLIENT_HAS_ULTRALIGHT
#include <Ultralight/Ultralight.h>
#include <vector>
#include <algorithm>
#include <fstream>
#include <sstream>
#endif

UltraLightManager g_ultralightManager;

UltraLightManager& UltraLightManager::instance()
{
    return g_ultralightManager;
}

#ifdef OTCLIENT_HAS_ULTRALIGHT

static ultralight::RefPtr<ultralight::Renderer> s_renderer;

// ---- Simple FileSystem implementation ----
class SimpleFileSystem : public ultralight::FileSystem {
public:
    bool FileExists(const ultralight::String& file_path) override
    {
        auto upath = file_path.utf8();
        std::ifstream f(upath.data());
        return f.good();
    }

    ultralight::String GetFileMimeType(const ultralight::String& file_path) override
    {
        auto upath = file_path.utf8();
        std::string path(upath.data());
        auto dot = path.find_last_of('.');
        if (dot != std::string::npos) {
            auto ext = path.substr(dot);
            if (ext == ".html" || ext == ".htm") return ultralight::String("text/html");
            if (ext == ".css") return ultralight::String("text/css");
            if (ext == ".js") return ultralight::String("text/javascript");
            if (ext == ".png") return ultralight::String("image/png");
            if (ext == ".jpg" || ext == ".jpeg") return ultralight::String("image/jpeg");
            if (ext == ".svg") return ultralight::String("image/svg+xml");
            if (ext == ".json") return ultralight::String("application/json");
        }
        return ultralight::String("application/unknown");
    }

    ultralight::String GetFileCharset(const ultralight::String& file_path) override
    {
        auto mime = GetFileMimeType(file_path).utf8();
        std::string mimeStr(mime.data());
        if (mimeStr.find("text/") == 0 || mimeStr.find("application/json") == 0
            || mimeStr.find("application/javascript") == 0)
            return ultralight::String("utf-8");
        return ultralight::String();
    }

    ultralight::RefPtr<ultralight::Buffer> OpenFile(const ultralight::String& file_path) override
    {
        auto upath = file_path.utf8();
        std::ifstream f(upath.data(), std::ios::binary | std::ios::ate);
        if (!f) return nullptr;
        auto size = static_cast<size_t>(f.tellg());
        f.seekg(0);
        auto buf = std::make_unique<char[]>(size);
        f.read(buf.get(), size);
        auto result = ultralight::Buffer::CreateFromCopy(buf.get(), size);
        return result;
    }
};

static SimpleFileSystem s_fileSystem;

// ---- Simple FontLoader implementation (DirectWrite on Windows) ----
class SimpleFontLoader : public ultralight::FontLoader {
public:
    ultralight::String fallback_font() const override
    {
        return ultralight::String("Arial");
    }

    ultralight::String fallback_font_for_characters(const ultralight::String& characters,
                                                     int weight, bool italic) const override
    {
        (void)characters; (void)weight; (void)italic;
        return ultralight::String("Arial");
    }

    ultralight::RefPtr<ultralight::FontFile> Load(const ultralight::String& family,
                                                   int weight, bool italic) override
    {
        (void)weight; (void)italic;
        auto ufam = family.utf8();
        std::string fam(ufam.data());
        std::string winDir = "C:\\Windows\\Fonts\\";
        std::string path;

        if (fam == "Arial" || fam == "sans-serif" || fam == "Times New Roman" || fam == "serif")
            path = winDir + "arial.ttf";
        else if (fam == "Courier New" || fam == "monospace" || fam == "fixed")
            path = winDir + "cour.ttf";
        else
            path = winDir + "arial.ttf";

        if (std::ifstream(path.c_str()).good())
            return ultralight::FontFile::Create(ultralight::String(path.c_str()));

        return nullptr;
    }
};

static SimpleFontLoader s_fontLoader;

// ---- Simple Logger implementation ----
class SimpleLogger : public ultralight::Logger {
public:
    void LogMessage(ultralight::LogLevel level, const ultralight::String& message) override
    {
        auto msg = message.utf8();
        switch (level) {
            case ultralight::LogLevel::Error:
                g_logger.error(std::string("Ultralight: ") + msg.data());
                break;
            case ultralight::LogLevel::Warning:
                g_logger.warning(std::string("Ultralight: ") + msg.data());
                break;
            default:
                g_logger.info(std::string("Ultralight: ") + msg.data());
                break;
        }
    }
};

static SimpleLogger s_logger;

// ---- URL decode helper ----
static std::string uri_decode(const std::string& input)
{
    std::string result;
    result.reserve(input.size());
    for (size_t i = 0; i < input.size(); ++i) {
        if (input[i] == '%' && i + 2 < input.size()) {
            auto hex = input.substr(i + 1, 2);
            char* end = nullptr;
            long ch = std::strtol(hex.c_str(), &end, 16);
            if (end == hex.c_str() + 2) {
                result += static_cast<char>(ch);
                i += 2;
                continue;
            }
        }
        result += input[i];
    }
    return result;
}

// ---- Event conversion helpers ----
static ultralight::KeyEvent toUltralightKeyEvent(const InputEvent& event)
{
    ultralight::KeyEvent uvEvent;
    uvEvent.type = event.type == Fw::KeyDownInputEvent ? ultralight::KeyEvent::kType_RawKeyDown
                  : event.type == Fw::KeyUpInputEvent   ? ultralight::KeyEvent::kType_KeyUp
                  : ultralight::KeyEvent::kType_Char;
    uvEvent.virtual_key_code = event.keyCode;
    uvEvent.native_key_code = event.keyCode;
    uvEvent.text = ultralight::String8(event.keyText.c_str());
    uvEvent.unmodified_text = ultralight::String8(event.keyText.c_str());
    uvEvent.is_keypad = false;
    uvEvent.modifiers = event.keyboardModifiers;
    return uvEvent;
}

static ultralight::MouseEvent toUltralightMouseEvent(const InputEvent& event)
{
    ultralight::MouseEvent uvEvent;
    uvEvent.x = event.mousePos.x;
    uvEvent.y = event.mousePos.y;
    switch (event.mouseButton) {
        case Fw::MouseLeftButton:  uvEvent.button = ultralight::MouseEvent::kButton_Left; break;
        case Fw::MouseRightButton: uvEvent.button = ultralight::MouseEvent::kButton_Right; break;
        case Fw::MouseMidButton:   uvEvent.button = ultralight::MouseEvent::kButton_Middle; break;
        default:                   uvEvent.button = ultralight::MouseEvent::kButton_None; break;
    }
    switch (event.type) {
        case Fw::MousePressInputEvent:   uvEvent.type = ultralight::MouseEvent::kType_MouseDown; break;
        case Fw::MouseReleaseInputEvent: uvEvent.type = ultralight::MouseEvent::kType_MouseUp; break;
        case Fw::MouseMoveInputEvent:    uvEvent.type = ultralight::MouseEvent::kType_MouseMoved; break;
        default: break;
    }
    return uvEvent;
}

// ---- View/Load bridge ----
class UltraViewBridge : public ultralight::LoadListener, public ultralight::ViewListener {
public:
    void OnDOMReady(ultralight::View* caller, uint64_t frame_id, bool is_main_frame,
                    const ultralight::String& url) override
    {
        (void)frame_id; (void)is_main_frame; (void)url;
        caller->EvaluateScript(ultralight::String(
            "window.callLuaFunction = function() {"
            "  var payload = arguments[0];"
            "  for (var i = 1; i < arguments.length; i++) {"
            "    payload += '|' + encodeURIComponent(String(arguments[i]));"
            "  }"
            "  document.title = '__otc_lua__' + payload;"
            "  return true;"
            "};"
        ));
    }

    void OnChangeTitle(ultralight::View* caller, const ultralight::String& title) override
    {
        (void)caller;
        auto title8 = title.utf8();
        std::string titleStr(title8.data());
        if (titleStr.size() >= 11 && titleStr.substr(0, 11) == "__otc_lua__") {
            auto payload = titleStr.substr(11);
            auto pipePos = payload.find('|');
            std::string functionPath = payload.substr(0, pipePos);
            std::vector<std::string> args;
            if (pipePos != std::string::npos) {
                auto remaining = payload.substr(pipePos + 1);
                size_t start = 0, end;
                while ((end = remaining.find('|', start)) != std::string::npos) {
                    args.push_back(uri_decode(remaining.substr(start, end - start)));
                    start = end + 1;
                }
                if (start < remaining.length())
                    args.push_back(uri_decode(remaining.substr(start)));
            }
            g_ultralightManager.dispatchLuaFunction(functionPath, args);
        }
    }
};

static UltraViewBridge s_bridge;

#endif

bool UltraLightManager::initialize()
{
    if (m_initialized) return true;

#ifdef OTCLIENT_HAS_ULTRALIGHT
    ultralight::Config config;

    auto baseDir = detectUltralightBaseDir();
    if (!baseDir.empty()) {
        config.resource_path_prefix = ultralight::String8((baseDir + "/resources/").c_str());
        config.cache_path = ultralight::String8((baseDir + "/cache").c_str());
    }

    auto& platform = ultralight::Platform::instance();
    platform.set_config(config);
    platform.set_font_loader(&s_fontLoader);
    platform.set_file_system(&s_fileSystem);
    platform.set_logger(&s_logger);

    s_renderer = ultralight::Renderer::Create();
    m_initialized = true;
    g_logger.info("Ultralight initialized successfully");
    return true;
#else
    g_logger.warning("Ultralight: SDK not available at compile time");
    return false;
#endif
}

void UltraLightManager::update()
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    if (!m_initialized || !s_renderer) return;
    s_renderer->Update();
#endif
}

void UltraLightManager::render(Painter& painter)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    if (!m_initialized || !s_renderer) return;

    s_renderer->Render();

    painter.resetClipRect();
    painter.resetTransformMatrix();
    painter.setCompositionMode(Painter::CompositionMode_Normal);
    painter.setColor(Color::white);

    for (auto& [name, viewData] : m_views) {
        if (!viewData.visible || !viewData.view) continue;

        auto* view = static_cast<ultralight::View*>(viewData.view);
        auto* bitmapSurface = static_cast<ultralight::BitmapSurface*>(view->surface());
        if (!bitmapSurface) continue;

        auto bitmap = bitmapSurface->bitmap();
        if (!bitmap) continue;

        auto w = bitmap->width();
        auto h = bitmap->height();
        if (w == 0 || h == 0) continue;

        if (!viewData.texture || viewData.texture->getSize() != Size(w, h)) {
            viewData.texture = std::make_shared<Texture>(Size(w, h));
        }

        auto& texture = viewData.texture;
        texture->update();

        auto rawPixels = bitmap->LockPixels();
        if (!rawPixels) continue;

        bitmap->SwapRedBlueChannels();

        auto image = std::make_shared<Image>(Size(w, h), 4, static_cast<uint8_t*>(rawPixels));
        texture->replace(image);
        texture->update();

        bitmap->UnlockPixels();

        CoordsBuffer quad;
        Rect dest(viewData.x, viewData.y, static_cast<int>(w), static_cast<int>(h));
        Rect src(0, 0, static_cast<int>(w), static_cast<int>(h));
        quad.addRect(dest, src);
        painter.setTexture(texture);
        painter.drawCoords(quad, Painter::Triangles);
    }
#endif
}

void UltraLightManager::shutdown()
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    for (auto& [name, viewData] : m_views) {
        if (viewData.view) {
            auto* view = static_cast<ultralight::View*>(viewData.view);
            view->set_load_listener(nullptr);
            view->set_view_listener(nullptr);
        }
        viewData.texture = nullptr;
    }
    m_views.clear();
    s_renderer = nullptr;
    m_initialized = false;
    g_logger.info("Ultralight shutdown");
#endif
}

bool UltraLightManager::createView(const std::string& name, int width, int height, const std::string& htmlPath)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    if (!m_initialized || !s_renderer) return false;

    ultralight::ViewConfig viewConfig;
    viewConfig.is_accelerated = false;
    viewConfig.is_transparent = true;

    auto view = s_renderer->CreateView(static_cast<uint32_t>(width), static_cast<uint32_t>(height), viewConfig, nullptr);
    if (!view) return false;

    view->set_load_listener(&s_bridge);
    view->set_view_listener(&s_bridge);

    ViewData vd;
    vd.view = view.get();
    vd.visible = true;
    vd.focused = false;

    m_views[name] = vd;

    if (!htmlPath.empty())
        loadFile(name, htmlPath);

    return true;
#else
    (void)name; (void)width; (void)height; (void)htmlPath;
    return false;
#endif
}

void UltraLightManager::removeView(const std::string& name)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    auto it = m_views.find(name);
    if (it != m_views.end()) {
        if (it->second.view) {
            auto* view = static_cast<ultralight::View*>(it->second.view);
            view->set_load_listener(nullptr);
            view->set_view_listener(nullptr);
        }
        it->second.texture = nullptr;
        m_views.erase(it);
    }
#else
    (void)name;
#endif
}

void UltraLightManager::setViewVisible(const std::string& name, bool visible)
{
    auto it = m_views.find(name);
    if (it != m_views.end())
        it->second.visible = visible;
}

void UltraLightManager::setViewPosition(const std::string& name, int x, int y)
{
    auto it = m_views.find(name);
    if (it != m_views.end()) {
        it->second.x = x;
        it->second.y = y;
    }
}

void UltraLightManager::setViewFocus(const std::string& name, bool focused)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    auto it = m_views.find(name);
    if (it != m_views.end() && it->second.view) {
        it->second.focused = focused;
        auto* view = static_cast<ultralight::View*>(it->second.view);
        view->Focus();
    }
#else
    (void)name; (void)focused;
#endif
}

bool UltraLightManager::hasView(const std::string& name)
{
    return m_views.find(name) != m_views.end();
}

bool UltraLightManager::isViewVisible(const std::string& name)
{
    auto it = m_views.find(name);
    return it != m_views.end() && it->second.visible;
}

void UltraLightManager::loadFile(const std::string& name, const std::string& htmlPath)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    auto it = m_views.find(name);
    if (it == m_views.end() || !it->second.view) return;

    auto* view = static_cast<ultralight::View*>(it->second.view);
    auto baseDir = detectUltralightBaseDir();
    auto url = "file:///" + baseDir + htmlPath;
    view->LoadURL(ultralight::String(url.c_str()));
#endif
}

void UltraLightManager::callJSFunction(const std::string& viewName, const std::string& functionName, const std::string& argsJson)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    auto it = m_views.find(viewName);
    if (it == m_views.end() || !it->second.view) return;

    auto* view = static_cast<ultralight::View*>(it->second.view);
    std::string script = functionName + "(" + argsJson + ");";
    view->EvaluateScript(ultralight::String(script.c_str()));
#else
    (void)viewName; (void)functionName; (void)argsJson;
#endif
}

std::string UltraLightManager::getItemSpriteDataUri(uint16 itemId)
{
    return "";
}

bool UltraLightManager::handleInputEvent(const InputEvent& event)
{
#ifdef OTCLIENT_HAS_ULTRALIGHT
    if (!m_initialized) return false;

    switch (event.type) {
        case Fw::KeyDownInputEvent:
        case Fw::KeyUpInputEvent:
        case Fw::KeyPressInputEvent: {
            for (auto& [name, vd] : m_views) {
                if (vd.visible && vd.focused && vd.view) {
                    auto* view = static_cast<ultralight::View*>(vd.view);
                    view->FireKeyEvent(toUltralightKeyEvent(event));
                    return true;
                }
            }
            break;
        }
        case Fw::MousePressInputEvent:
        case Fw::MouseReleaseInputEvent:
        case Fw::MouseMoveInputEvent: {
            for (auto& [name, vd] : m_views) {
                if (!vd.visible || !vd.view) continue;
                auto* view = static_cast<ultralight::View*>(vd.view);
                int vw = static_cast<int>(view->width());
                int vh = static_cast<int>(view->height());
                Rect viewRect(vd.x, vd.y, vw, vh);
                if (viewRect.contains(event.mousePos)) {
                    view->FireMouseEvent(toUltralightMouseEvent(event));
                    if (event.type == Fw::MousePressInputEvent)
                        vd.focused = true;
                    return true;
                }
            }
            break;
        }
        case Fw::MouseWheelInputEvent: {
            for (auto& [name, vd] : m_views) {
                if (!vd.visible || !vd.view) continue;
                auto* view = static_cast<ultralight::View*>(vd.view);
                int vw = static_cast<int>(view->width());
                int vh = static_cast<int>(view->height());
                Rect viewRect(vd.x, vd.y, vw, vh);
                if (viewRect.contains(event.mousePos)) {
                    ultralight::ScrollEvent scrollEvent;
                    scrollEvent.type = ultralight::ScrollEvent::kType_ScrollByPixel;
                    scrollEvent.delta_x = 0;
                    scrollEvent.delta_y = event.wheelDirection == Fw::MouseWheelUp ? -32 : 32;
                    view->FireScrollEvent(scrollEvent);
                    return true;
                }
            }
            break;
        }
        default:
            break;
    }
#else
    (void)event;
#endif
    return false;
}

void UltraLightManager::dispatchLuaFunction(const std::string& functionPath, const std::vector<std::string>& args)
{
    if (functionPath.empty()) return;

    auto dotPos = functionPath.find('.');
    if (dotPos == std::string::npos) {
        g_lua.callGlobalField(functionPath, "()");
        return;
    }

    std::string global = functionPath.substr(0, dotPos);
    std::string field = functionPath.substr(dotPos + 1);

    auto argsStr = stdext::format("(");
    for (size_t i = 0; i < args.size(); ++i) {
        if (i > 0) argsStr += ", ";
        argsStr += "'" + args[i] + "'";
    }
    argsStr += ")";

    g_lua.evaluateExpression(global + "." + field + argsStr);
}

std::string UltraLightManager::detectUltralightBaseDir()
{
    std::vector<std::string> candidates = {
        g_platform.getTempPath() + "/ultralight",
        ".",
        "../ultralight-sdk",
        "../../ultralight-sdk",
    };

    for (auto& dir : candidates) {
        if (g_platform.fileExists(dir + "/resources/cacert.pem"))
            return dir;
    }
    return "";
}
