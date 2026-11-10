#include "4DPlugin-Metaphone.cpp"
#include "support/4DPlugin-JSON.cpp"
#include "4D Plugin API/Classes/ARRAY_TEXT.h"
#include "4D Plugin API/Classes/C_TEXT.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#include <map>
#include <set>
#include <iostream>

// Only engine callbacks are modeled; the plugin, helpers and SDK are compiled intact.
struct Node {
    int refs = 1;
    std::map<std::u16string, PA_Variable> properties;
    std::vector<PA_Variable> elements;
};
static std::set<PA_Unichar*> strings;
static std::set<Node*> nodes;
static std::map<PA_Handle, size_t> handles;
static bool allocated_empty;

static void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << "\n";
        std::exit(1);
    }
}

static std::u16string text(PA_Unistring s) {
    if (!s.fString) {
        require(s.fLength == 0, "null nonempty string");
        return {};
    }
    PA_Unichar* p = s.fString;
    require(strings.count(p), "borrowed string no longer alive");
    require(s.fString[s.fLength] == 0, "missing UTF-16 terminator");
    return std::u16string(reinterpret_cast<char16_t*>(s.fString), s.fLength);
}

static PA_Unistring make_string(const std::u16string& s) {
    PA_Unistring result = {};
    result.fLength = static_cast<PA_long32>(s.size());
    if (!s.empty() || allocated_empty) {
        result.fString = new PA_Unichar[s.size() + 1]();
        std::copy(s.begin(), s.end(), result.fString);
        PA_Unichar* p = result.fString;
        strings.insert(p);
    }
    return result;
}

static void dispose(PA_Unistring s) {
    if (s.fString) {
        PA_Unichar* p = s.fString;
        require(strings.erase(p) == 1, "duplicate/unowned disposal");
        delete[] s.fString;
    }
}

static Node* node() {
    Node* n = new Node;
    nodes.insert(n);
    return n;
}

static void clear(PA_Variable& v);
static void release(Node* n) {
    if (!n) return;
    require(nodes.count(n), "dead object/collection reference");
    if (--n->refs == 0) {
        for (auto& item : n->properties) clear(item.second);
        for (auto& item : n->elements) clear(item);
        nodes.erase(n);
        delete n;
    }
}

static PA_Variable copy(PA_Variable v) {
    if (v.fType == eVK_Unistring)
        v.uValue.fString = make_string(text(v.uValue.fString));
    if (v.fType == eVK_Object || v.fType == eVK_Collection) {
        Node* n = static_cast<Node*>(v.uValue.fObject);
        if (n) {
            require(nodes.count(n), "copy of dead reference");
            ++n->refs;
        }
    }
    return v;
}

static void clear(PA_Variable& v) {
    if (v.fType == eVK_Unistring) dispose(v.uValue.fString);
    else if (v.fType == eVK_Object || v.fType == eVK_Collection)
        release(static_cast<Node*>(v.uValue.fObject));
    else if (v.fType == eVK_ArrayUnicode) {
        auto p = reinterpret_cast<PA_Unistring*>(*v.uValue.fArray.fData);
        for (int i = 0; i <= v.uValue.fArray.fNbElements; ++i) dispose(p[i]);
        PA_DisposeHandle(v.uValue.fArray.fData);
    }
    v = {};
    v.fType = eVK_Undefined;
}

static void engine(short selector, EngineBlock* eb) {
    switch (selector) {
    case EX_GET_INFORMATION:
        eb->fParam2 = 0x1700;
        break;
    case EX_CREATE_UNISTRING: {
        auto p = reinterpret_cast<const char16_t*>(eb->fHandle);
        eb->fUniString1 = make_string(p ? std::u16string(p) : std::u16string());
        break;
    }
    case EX_DISPOSE_UNISTRING:
        dispose(eb->fUniString1);
        break;
    case EX_SET_UNISTRING: {
        std::u16string s(reinterpret_cast<const char16_t*>(eb->fHandle));
        dispose(eb->fUniString1);
        eb->fUniString1 = make_string(s);
        break;
    }
    case EX_CLEAR_VARIABLE:
        clear(*static_cast<PA_Variable*>(eb->fPtr1));
        break;
    case EX_VARIABLE_TO_STRING: {
        auto v = reinterpret_cast<PA_Variable*>(eb->fHandle);
        require(v->fType == eVK_Unistring, "only string-valued getter modeled");
        eb->fUniString1 = v->uValue.fString;
        break;
    }
    case EX_HANDLE_MANAGER: {
        PA_Handle h = eb->fParam1 == 1 ? nullptr : eb->fHandle;
        const sLONG_PTR size = (eb->fParam1 == 1 || eb->fParam1 == 3) ? eb->fParam2 : 0;
        switch (eb->fParam1) {
        case 1:
            h = new char*;
            *h = new char[std::max<sLONG_PTR>(1, size)]();
            handles[h] = eb->fParam2;
            eb->fHandle = h;
            break;
        case 2:
            require(handles.erase(h) == 1, "unowned handle disposal");
            delete[] *h;
            delete h;
            break;
        case 3: {
            require(handles.count(h), "resize unowned handle");
            char* p = new char[std::max<sLONG_PTR>(1, size)]();
            memcpy(p, *h, std::min<size_t>(handles.at(h), eb->fParam2));
            delete[] *h;
            *h = p;
            handles[h] = eb->fParam2;
            break;
        }
        case 4: eb->fParam2 = handles.at(h); break;
        case 5: eb->fParam3 = reinterpret_cast<sLONG_PTR>(*h); break;
        case 6: break;
        default: require(false, "unexpected handle operation");
        }
        break;
    }
    case EX_EXECUTE_COMMAND_BY_ID: {
        auto result = static_cast<PA_Variable*>(eb->fPtr2);
        auto params = static_cast<PA_Variable**>(eb->fPtr1);
        if (eb->fParam1 == 1471 || eb->fParam1 == 1472) {
            result->fType = eb->fParam1 == 1471 ? eVK_Object : eVK_Collection;
            result->uValue.fObject = node();
        } else if (eb->fParam1 == 1231) {
            Node* n = static_cast<Node*>(params[0]->uValue.fObject);
            PA_SetBooleanVariable(result, n->properties.count(text(params[1]->uValue.fString)));
        } else if (eb->fParam1 == 1217) {
            result->fType = eVK_Unistring;
            result->uValue.fString = make_string(u"{}");
        } else if (eb->fParam1 == 1225) {
            Node* original = static_cast<Node*>(params[0]->uValue.fObject);
            Node* duplicate = node();
            for (auto& item : original->properties)
                duplicate->properties[item.first] = copy(item.second);
            result->fType = eVK_Object;
            result->uValue.fObject = duplicate;
        } else require(false, "unexpected command");
        break;
    }
    case EX_GET_OBJ_VALUE: {
        auto n = static_cast<Node*>(eb->fPtr1);
        auto v = static_cast<PA_Variable*>(eb->fPtr2);
        if (eb->fShort == eVK_Collection && eb->fLongint == -1)
            PA_SetLongintVariable(v, static_cast<PA_long32>(n->elements.size()));
        else if (eb->fShort == eVK_Collection)
            *v = copy(n->elements.at(eb->fLongint));
        else *v = copy(n->properties.at(text(eb->fUniString1)));
        break;
    }
    case EX_SET_OBJ_VALUE: {
        auto n = static_cast<Node*>(eb->fPtr1);
        auto v = static_cast<PA_Variable*>(eb->fPtr2);
        PA_Variable* target;
        if (eb->fShort == eVK_Collection) {
            if (static_cast<size_t>(eb->fLongint) == n->elements.size())
                n->elements.push_back(PA_CreateVariable(eVK_Undefined));
            target = &n->elements.at(eb->fLongint);
        } else target = &n->properties[text(eb->fUniString1)];
        PA_Variable independent = copy(*v);
        clear(*target);
        *target = independent;
        break;
    }
    case EX_CONVERT_CHARSET_TO_CHARSET: {
        CFStringEncoding from = eb->fParam2 == eVTC_UTF_16
            ? kCFStringEncodingUTF16LE : kCFStringEncodingMacRoman;
        CFStringEncoding to = eb->fParam4 == eVTC_UTF_16
            ? kCFStringEncodingUTF16LE : kCFStringEncodingMacRoman;
        CFStringRef s = CFStringCreateWithBytes(nullptr,
            static_cast<UInt8*>(eb->fPtr1), eb->fParam1, from, false);
        require(s != nullptr, "invalid conversion input");
        CFIndex bytes = 0;
        CFIndex converted = CFStringGetBytes(s, CFRangeMake(0, CFStringGetLength(s)),
            to, '?', false, static_cast<UInt8*>(eb->fPtr2), eb->fParam3, &bytes);
        require(converted == CFStringGetLength(s), "insufficient conversion capacity");
        require(bytes <= eb->fParam3, "conversion exceeded byte capacity");
        eb->fParam3 = bytes; // SDK returns bytes, excludes terminator.
        CFRelease(s);
        break;
    }
    default:
        std::cerr << "selector: " << selector << "\n";
        require(false, "unexpected engine callback");
    }
    eb->fError = eER_NoErr;
}

static PA_Unichar* chars(const char16_t* s) {
    return reinterpret_cast<PA_Unichar*>(const_cast<char16_t*>(s));
}

static void balanced() {
    require(strings.empty(), "outstanding SDK string allocations");
    require(nodes.empty(), "outstanding object/collection references");
    require(handles.empty(), "outstanding SDK handles");
}

static void outputs(bool command) {
    for (int i = 0; i < 50; ++i) {
        PA_CollectionRef result;
        if (command) {
            PA_Unistring input = PA_CreateUnistring(chars(i % 2 ? u"SMITH" : u""));
            PA_Unistring* args[] = {&input};
            PluginBlock params = {};
            params.fParameters = args;
            params.fResult = &result;
            PluginMain(1, &params);
            require(text(input) == (i % 2 ? u"SMITH" : u""), "input mutated");
            PA_DisposeUnistring(&input);
        } else {
            result = PA_CreateCollection();
            for (auto s : {"ASCII", "", "", "ASCII"}) push_back(result, s);
        }
        Node* n = static_cast<Node*>(result);
        require(n->elements.size() == (command ? 2 : 4), "wrong output count");
        const char16_t* expected[] = {command ? (i % 2 ? u"SM0" : u"") : u"ASCII",
            command ? (i % 2 ? u"XMT" : u"") : u"", u"", u"ASCII"};
        for (size_t j = 0; j < n->elements.size(); ++j)
            require(text(n->elements[j].uValue.fString) == expected[j], "wrong exact code");
        if (allocated_empty || i % 2 || !command)
            require(n->elements[0].uValue.fString.fString != n->elements[1].uValue.fString.fString,
                "outputs share allocation");
        release(n);
        balanced();
    }
}

static void setters() {
    auto obj = PA_CreateObject();
    struct Fixture {
        const char16_t* u16;
        const wchar_t* wide;
        const char* utf8;
    };
    const Fixture fixtures[] = {
        {u"ASCII", L"ASCII", "ASCII"},
        {u"\u00e9\u6f22", L"\u00e9\u6f22", "\xc3\xa9\xe6\xbc\xa2"},
        {u"\U0001f600", L"\U0001f600", "\xf0\x9f\x98\x80"},
        {u"", L"", ""},
    };
    for (auto fixture : fixtures) {
        CUTF16String u(chars(fixture.u16));
        ob_set_a(obj, L"key", &u);
        require(text(static_cast<Node*>(obj)->properties.at(u"key").uValue.fString) == fixture.u16,
            "UTF-16 setter content");
        ob_set_a(obj, L"key", fixture.wide);
        require(text(static_cast<Node*>(obj)->properties.at(u"key").uValue.fString)
            == fixture.u16, "wide setter content");
        ob_set_s(obj, L"key", fixture.utf8);
        require(text(static_cast<Node*>(obj)->properties.at(u"key").uValue.fString)
            == fixture.u16, "UTF-8 wide-key content");
        ob_set_s(obj, "key", fixture.utf8);
        require(text(static_cast<Node*>(obj)->properties.at(u"key").uValue.fString) == fixture.u16,
            "UTF-8 narrow-key content");
    }
    release(static_cast<Node*>(obj));
    balanced();
}

static void getters(const std::string& kind) {
    Node* obj = static_cast<Node*>(PA_CreateObject());
    CUTF16String s(chars(u"\u00e9\U0001f600"));
    ob_set_a(obj, L"key", &s);
    const size_t owned = strings.size();
    CUTF8String out;
    if (kind == "getter-string") {
        require(ob_get_a(obj, L"key", &out), "missing string property");
        require(out == CUTF8String(reinterpret_cast<const uint8_t*>("\xc3\xa9\xf0\x9f\x98\x80")),
            "getter exact UTF-8 content");
        require(strings.size() == owned, "string getter leaked owning result");
    } else if (kind == "getter-boolean")
        require(!ob_get_b(obj, L"key"), "boolean mismatch result");
    else if (kind == "getter-number")
        require(ob_get_n(obj, L"key") == 0, "numeric mismatch result");
    else require(ob_get_c(obj, L"key") == nullptr, "collection mismatch result");
    require(strings.size() == owned, "mismatched getter leaked owning result");
    ob_set_b(obj, L"key", true);
    require(ob_get_b(obj, L"key"), "boolean getter");
    ob_set_n(obj, L"key", 42.5);
    require(ob_get_n(obj, L"key") == 42.5, "numeric getter");
    ob_stringify(obj, &out);
    require(out == CUTF8String(reinterpret_cast<const uint8_t*>("{}")), "stringify output");
    Node* child = static_cast<Node*>(PA_CreateObject());
    ob_set_o(obj, L"child", child);
    require(child->refs == 1, "object handoff changed");
    auto collection = PA_CreateCollection();
    push_back(collection, "ASCII");
    ob_set_c(obj, L"key", collection); // Existing owning handoff consumes this ref.
    require(!ob_get_b(obj, L"key"), "collection/boolean mismatch");
    require(ob_get_n(obj, L"key") == 0, "collection/numeric mismatch");
    require(ob_get_a(obj, L"key", &out), "collection/string mismatch presence");
    require(static_cast<Node*>(collection)->refs == 1, "mismatches leaked collection refs");
    auto handed_off = ob_get_c(obj, L"key");
    require(handed_off == collection && static_cast<Node*>(collection)->refs == 2,
        "successful collection getter must hand off owning reference");
    release(obj);
    require(text(static_cast<Node*>(handed_off)->elements[0].uValue.fString) == u"ASCII",
        "returned collection invalid after original owner release");
    release(static_cast<Node*>(handed_off));
    balanced();
}

static void arrays() {
    PA_Variable arr = PA_CreateVariable(eVK_ArrayUnicode);
    unsigned char* params[] = {reinterpret_cast<unsigned char*>(&arr)};
    {
        ARRAY_TEXT source;
        for (auto s : {u"", u"ASCII", u"\u00e9\u6f22", u"\U0001f600"})
            source.appendUTF16String(chars(s));
        source.toParamAtIndex(params, 1);
        ARRAY_TEXT snapshot;
        snapshot.fromParamAtIndex(params, 1);
        const char16_t* expected[] = {u"", u"ASCII", u"\u00e9\u6f22", u"\U0001f600"};
        for (int i = 0; i < 4; ++i) {
            CUTF16String actual;
            snapshot.copyUTF16StringAtIndex(&actual, i);
            require(actual == CUTF16String(chars(expected[i])), "array exact UTF-16 content");
        }
        source.toParamAtIndex(params, 1); // Replacement disposes only old owners.
        source.setSize(2);
        source.toParamAtIndex(params, 1); // Shrink removes old strings.
        CUTF16String preserved;
        snapshot.copyUTF16StringAtIndex(&preserved, 3);
        require(preserved == CUTF16String(chars(u"\U0001f600")), "borrowed input not copied");
        require(text(PA_GetStringInArray(arr, 1)) == u"ASCII", "array content");
    }
    PA_Unistring value = PA_CreateUnistring(chars(u"independent"));
    PA_Variable wrong = PA_CreateVariable(eVK_Longint);
    PA_SetStringInArray(wrong, 0, &value);
    PA_SetStringInArray(arr, -1, &value);
    PA_SetStringInArray(arr, 2, &value);
    PA_Variable null_data = {};
    null_data.fType = eVK_ArrayUnicode;
    PA_SetStringInArray(null_data, 0, &value);
    PA_SetStringInArray(arr, 0, nullptr);
    require(text(value) == u"independent", "rejection consumed input");
    PA_DisposeUnistring(&value);
    PA_ClearVariable(&arr);
    balanced();
}

static void scalar_text() {
    for (auto s : {u"ASCII", u"\u00e9\u6f22", u"\U0001f600", u""}) {
        PA_Unistring input = PA_CreateUnistring(chars(s));
        unsigned char* params[] = {reinterpret_cast<unsigned char*>(&input)};
        C_TEXT copied;
        copied.fromParamAtIndex(params, 1);
        PA_SetUnistring(&input, chars(u"replacement"));
        require(CUTF16String(copied.getUTF16StringPtr(), copied.getUTF16Length())
            == CUTF16String(chars(s)), "scalar getter did not copy borrowed input");
        copied.toParamAtIndex(params, 1);
        require(text(input) == s, "scalar setter exact UTF-16 content");
        PA_DisposeUnistring(&input);
        balanced();
    }
}

int main(int argc, char** argv) {
    require(argc == 3, "usage: ownership CASE allocated|null");
    allocated_empty = std::string(argv[2]) == "allocated";
    gCall4D = engine;
    std::string test = argv[1];
    if (test == "command") outputs(true);
    else if (test == "outputs") outputs(false);
    else if (test == "setters") setters();
    else if (test.find("getter-") == 0) getters(test);
    else if (test == "arrays") arrays();
    else if (test == "text") scalar_text();
    else require(false, "unknown test");
    balanced();
    std::cout << test << "/" << argv[2] << ": PASS\n";
}
