# Godot 4 Migration Analysis — "Idle Pioneer" / "Colonial Frontiers"

**Session A: read-only archaeology of the Unity repository.**
No Godot code written. No files outside `docs/` modified.

- **Repo root:** `E:\Unity\Projects\Idle Pioneer`
- **Unity version:** 6000.3.2f1 (`ProjectSettings/ProjectVersion.txt`)
- **Render pipeline:** URP 17.3.0, 2D renderer (`Packages/manifest.json`, `Assets/Settings/Renderer2D.asset`)
- **Git:** single commit `f863789 "State as of 8 months ago, before Godot migration"`, working tree clean
- **Project scripts:** 42 C# files, ~5,979 lines (`Assets/01_Scripts/`)
- **Scenes:** 1 real scene (`Assets/Scenes/SampleScene.unity`, 10,299 lines) + 32 TextMesh Pro sample scenes
- **Data assets:** 131 `.asset` files, of which 93 are project data and the rest TMP/URP settings
- **Asset serialization:** Force Text — every `.asset` is human-readable YAML. This matters a lot; see §B.

Every claim below cites a file. Phase 2 conclusions are tagged **CONFIRMED** / **INFERRED** / **PROPOSED**.

---

# PHASE 1 — Portability classification

## Summary table

| Bucket | Count | Verdict |
|---|---|---|
| A. Pure logic (portable ~as-is) | 4 files + ~6 embeddable fragments | Copy with edits |
| B. Data definitions (ScriptableObjects) | 8 SO types, 93 asset instances | Re-author schema; **data values are machine-extractable** |
| C. Unity-coupled code (rewrite) | 30 MonoBehaviours + 4 Editor tools | Rewrite against Godot node/signal model |
| D. Art & audio | 25 PNG + 12 JPG + 2 TTF (project), 0 audio | Raw files import; metadata does not |
| E. Dead / abandoned | ~9 scripts + several assets | Do not port |

---

## A. PURE LOGIC — portable almost as-is

Godot 4 supports C#, so anything with no `UnityEngine` type in its signature can be moved with only namespace edits. Honestly, this tier is **thin** — the project has very little logic that is not wearing a MonoBehaviour.

### A1. Genuinely engine-free types (copy directly)

| Item | File | Notes |
|---|---|---|
| `enum ResourceCategory` (16 values) | `Assets/01_Scripts/ResourceData.cs:31-50` | Pure enum. Copy verbatim. |
| `enum ResearchCategory` (7 values) | `Assets/01_Scripts/ResearchData.cs:157-166` | Pure enum. Copy verbatim. |
| `enum ResearchEffectType` (18 values) | `Assets/01_Scripts/ResearchData.cs:171-191` | Pure enum. **Copy verbatim and preserve ordinal order** — the `.asset` files store `effectType` as an integer index (§B4). |
| `enum TransportType` | `Assets/01_Scripts/TransportVehicleData.cs:36-40` | Copy verbatim. |
| `enum VehicleState` | `Assets/01_Scripts/TransportVehicle.cs` (bottom) | Copy verbatim. |
| `enum TileType { DeepSea, ShallowSea, Land, Coast }` | `Assets/01_Scripts/MapManager.cs:6` | Copy verbatim — this is the land/water tag vocabulary (§Phase 2). |
| `enum DashboardTab` | `Assets/01_Scripts/DashboardController.cs:6` | Copy verbatim. |
| `class ResourceCost { ResourceData resource; int amount; }` | `Assets/01_Scripts/TransportVehicleData.cs:42-47` | Field type must be re-pointed at a Godot `Resource`. |

### A2. Engine-free math/algorithms embedded inside MonoBehaviours (extract, then copy)

These are the pieces genuinely worth salvaging. Each is a self-contained algorithm; only the surrounding class is Unity-bound.

| Algorithm | Location | Unity dependency | Portability |
|---|---|---|---|
| Exponential colony cost `base * mult^n` | `EconomyManager.cs:27` (`nextColonyCost => baseColonyCost * Mathf.Pow(costMultiplier, boughtColoniesCount)`) | only `Mathf.Pow` → `Math.Pow` | Trivial |
| Prestige multiplier `1 + 0.1 * doubloons` | `PrestigeManager.cs:35-38` | none | Trivial |
| Production accumulator with catch-up cycles | `ColonyProduction.cs:118-135` (`currentCycleTime += dt`, `cyclesCompleted = floor(t/modTime)`, `t %= modTime`) | `Mathf.FloorToInt` | Trivial — this is the correct offline/batch-tick shape and is worth keeping conceptually |
| Multiplicative bonus stacking | `ResearchManager.cs:207-231` (`GetProductionMultiplier`: global × per-resource × per-category) | none | Trivial — dictionary math only |
| Highest-value-first cargo loading | `TransportManager.cs` `CollectAndDepart` (`OrderByDescending(kvp => kvp.Key.baseValue)`, fill to `cargoCapacity`) | LINQ only | Trivial |
| Auto-sell "sell everything above threshold" sweep | `ResourceManager.cs:238-268` (`ProcessAutoSell`) | none in the loop body | Trivial |
| Prerequisite gate + visibility rules | `ResearchData.cs:56-121` (`CanResearch`, `IsVisible`) | none except `Debug.Log` | Trivial — but currently lives *on the data object*, which is an anti-pattern to fix in the rewrite |
| Bresenham line raster | `MapManager.cs` `DrawLineOnTexture` | `Mathf.Abs`, `Color32`, `Texture2D.SetPixel` | Algorithm portable; the write target changes to `Image.set_pixel` / `ImageTexture` |
| Perlin coastline + organic island generation | `MapManager.cs:36-80` | `Mathf.PerlinNoise`, `Mathf.Lerp`, `Random.Range` | Algorithm portable; Godot's `FastNoiseLite` replaces `Mathf.PerlinNoise` but **is not value-identical** — output maps will differ. See §E. |

### A3. Explicitly NOT in this bucket (worth stating)

There are **no** save-data structs, **no** serializable save model, and **no** pure-C# economy service. Persistence is three ad-hoc `PlayerPrefs` keys:

- `"LastSaveTime"` — a `DateTime.ToBinary()` string (`IdleManager.cs:105-109`)
- `"CompletedResearch"` — a comma-joined list of asset names (`ResearchManager.cs:412-427`) — **currently commented out at both call sites** (`ResearchManager.cs:59`, `:88`)
- No key at all for gold, doubloons, inventory, colonies, or vehicles

**There is no working save system to port.** Design one fresh in Session B.

---

## B. DATA DEFINITIONS — portable in concept, not in format

### B0. The good news, up front

`ProjectSettings` uses **Force Text** serialization, so every `.asset` is readable YAML, e.g. `Assets/03_Data/Resources/Timber.asset`:

```yaml
  m_Name: Timber
  m_EditorClassIdentifier: Assembly-CSharp::ResourceData
  resourceName: Timber
  resourceIcon: {fileID: -6792093457207638105, guid: ecf0c59ced6cc8c46b31163d213d4cf2, type: 3}
  baseValue: 1
  isTradeGood: 0
```

Cross-references are `{fileID, guid}` pairs, and every `.meta` file maps a guid to a path. **A one-off script can therefore convert all 93 data assets into Godot `.tres` mechanically** rather than by hand re-authoring. That is the single biggest cost saving available in this migration. (PROPOSED — Session B decision.)

### B1. ScriptableObject types (8)

| SO type | File | Fields | Instances |
|---|---|---|---|
| `ResourceData` | `Assets/01_Scripts/ResourceData.cs` | `resourceName`, `resourceIcon`, `category` (enum), `baseValue` (float), `isTradeGood` (bool), `description` | 50 |
| `TradeGoodData : ResourceData` | `Assets/01_Scripts/TradeGoodData.cs` | + `List<Ingredient>{resource,amount}`, `craftingTime` | 10 |
| `RecipeData` | `Assets/01_Scripts/RecipeData.cs` | `recipeName`, `List<ResourceRequirement>{resource,amount}`, `output`, `outputAmount`, `baseCraftingTime` | 10 |
| `ResearchData` | `Assets/01_Scripts/ResearchData.cs` | `researchName`, `description`, `researchIcon`, `category`, `goldCost`, `resourceCosts[]`, `prerequisites[]`, `effectType`, `productionMultiplier`, `unlockedColonyType`, `unlockedRecipes[]`, `affectedResource`, `affectedCategory`, `gridPosition` (Vector2Int), `tier` | 24 |
| `ColonyTypeData` | `Assets/01_Scripts/ColonyTypeData.cs` | `typeName`, `icon`, `prefab`, `productionMultiplier`, `storageCapacity`, `description` | 5 |
| `NationalityData` | `Assets/01_Scripts/NationalityData.cs` | `nationalityName`, `startingColonyName`, `nationalityColor`, 6 multipliers | 6 |
| `TransportVehicleData` | `Assets/01_Scripts/TransportVehicleData.cs` | `vehicleName`, `vehicleIcon`, `vehiclePrefab`, `transportType`, `baseSpeed`, `cargoCapacity`, `purchaseCost` (double), `buildCosts[]`, `description` | 2 |
| `GameConfigData` | `Assets/01_Scripts/GameConfigData.cs` | production/economy/transport/mapgen tuning constants | **0 — no instance exists** |

`struct ResourceRequirement` (`RecipeData.cs:4-9`) and `struct TradeGoodData.Ingredient` are two names for the same shape; unify them in Godot.

### B2. Data asset inventory (93 files under `Assets/03_Data/`)

**Resources — 50** (`Assets/03_Data/Resources/*.asset`), created in 5 value tiers by `Editor/ResourceGenerator.cs:14-24`:

| Tier | `baseValue` | Members |
|---|---|---|
| 1 | 1 | Timber, Flax, Corn, Clay, Soft Pelts, Pine Resin, Raw Hemp, Iron Ore, Tallow, Wild Berries |
| 2 | 10 | Tobacco Leaves, Sugar Cane, Cotton, Wheat, Barley, Hops, Hides, Copper Ore, Beeswax, Salt |
| 3 | 50 | Coal, Silver Ore, Indigo, Coffee Beans, Cocoa Pods, Wool, Hardwood, Tin Ore, Grapes, Medicinal Herbs |
| 4 | 250 | Silk Threads, Whale Oil, Ivory, Exotic Spices, Tortoise Shells, Sulfur, Nitre, Gold Nuggets, Sandalwood, Teak Wood |
| 5 | 1000 | Raw Diamonds, Emeralds, Pearls, Ambergris, Ancient Artifacts, Obsidian, Cinnabar, Platinum Ore, Saffron, Marble |

> ⚠ **No resource asset serializes a `category` field.** `grep -l "category:" Assets/03_Data/Resources/*.asset` returns zero files — they were generated before `ResourceCategory` was added to `ResourceData.cs`. All 50 therefore deserialize as `Basic`. Every category-based research bonus is consequently a no-op. **The category assignment must be authored fresh during migration**; the comments at `ResourceData.cs:33-49` are the only surviving intent.

> ⚠ **Only 2 of 50 resources have an icon** (`Timber.asset`, `Flax.asset`). The other 48 point at `{fileID: 0}`.

**Trade goods — 10** (`Assets/03_Data/TradeGoods/`): Bricks, Candles, Cured Tobacco, Hard Bread, Iron Tools, Lumber, Rope, Sails, Simple Leather, Woven Cloth. All `baseValue: 50`, all `isTradeGood: 1`. Placeholder values — a `Lumber` (value 50) built from 2 `Timber` (value 1 each) is a 25× arbitrage, so the crafting economy is unbalanced by construction.

**Recipes — 10** (`Assets/03_Data/Recipes/`). Only **3 of 10 have inputs**:

| Recipe | Inputs | Output |
|---|---|---|
| `Lumber_Recipe` | 2 × Timber | 1 Lumber |
| `Bricks_Recipe` | 2 × Clay | 1 Bricks |
| `Rope_Recipe` | 2 × Raw Hemp | 1 Rope |
| Candles, Cured Tobacco, Hard Bread, Iron Tools, Sails, Simple Leather, Woven Cloth | **`inputs: []`** | 1 each |

The 7 empty-input recipes are free-money bugs (`RecipeData.CanCraft()` trivially returns true). The intended inputs must be re-derived from `Editor/TradeGoodGenerator.cs` and `RESEARCH_TREE_DESIGN.md`, or designed anew.

**Research — 24** (`Assets/03_Data/Research/Path{1..6}_*/`), 4 per path:

| Path | Nodes (gold cost) |
|---|---|
| 1 Expansion | Frontier Surveying (50), Land Grants (150), Settlement Charter (500), Efficient Logistics (750) |
| 2 Extraction | Primitive Tools (50), Logging Techniques (200), Forestry Management (350), Advanced Mining (400) |
| 3 Commerce | Trading Posts (25), Coastal Navigation (100), Maritime Trade Routes (600), Merchant Fleet (800) |
| 4 Crafting | Apprentice Workshop (75), Tool Maintenance (100), Journeyman Workshop (450), Parallel Production (700) |
| 5 Specialization | Agricultural Focus (100), Forestry Focus (100), Agricultural Advancement (500), Lumber Mill Operations (500) |
| 6 Governance | Town Criers (50), Census Records (200), Record Keeping (1000), Trade Office (1500) |

This is 24 of the **63 nodes** specified in `RESEARCH_TREE_DESIGN.md:474-482`. Path 7 (Cross-Path Synergies) and Path 8 (Military) exist only on paper.

**Colony types — 5** (`Assets/03_Data/ColonyTypes/`):

| Asset | `typeName` | `productionMultiplier` | `storageCapacity` |
|---|---|---|---|
| `ColonyType_Outpost` | Outpost | 0.75 | 75 |
| `ColonyType_Settlement` | Settlement | 1.5 | 250 |
| `ColonyType_Town` | Town | 2 | 500 |
| `ColonyType_City` | City | 3 | 1000 |
| `ColonyType_ProvincialCapital` | Provincial Capital | 5 | 2500 |

Note these diverge from the design doc's curve (0.75 / 1.0 / 1.25 / 1.5 / 2.0, `RESEARCH_TREE_DESIGN.md`), and "Metropolis" was renamed "Provincial Capital".

**Nationalities — 6** (`Assets/03_Data/Nationalities/`):

| Asset | Starting colony | Bonus |
|---|---|---|
| `EnglishData` | Jamestown | ship speed ×1.1 |
| `FrenchData` | Quebec | colony cost ×0.8 |
| `SpanishData` | Santo Domingo | gold sell ×1.25 |
| `DutchData` | New Amsterdam | extraction rate ×1.15 |
| `PortugueseData` | São Vicente | wagon speed ×1.3 |
| `ItalianData` | Nuova Venezia | liberty generation ×1.15 |

> ⚠ **All six have an empty `nationalityName:` field.** `ColonyProduction.CheckNationality()` (`ColonyProduction.cs:96-106`) compares `chosenNationality.nationalityName == "Dutch"` — this comparison can never be true. The Dutch bonus is dead. Names must be filled in during re-authoring.
>
> ⚠ `libertyGenerationMultiplier` has **no consumer anywhere in the codebase** — "Liberty" is a designed-but-unimplemented mechanic (see Phase 2).

**Transport vehicles — 2** (`Assets/03_Data/Transport/`):

| Asset | `transportType` | `baseSpeed` | `cargoCapacity` | `purchaseCost` |
|---|---|---|---|---|
| `Vehicle_Wagon` | 0 (Wagon) | 50 | 50 | 100 |
| `Vehicle_Ship` | **0 (Wagon)** ⚠ | 50 | 200 | 100 |

`Vehicle_Ship.asset` is mis-tagged as `transportType: 0`, i.e. Wagon. Since `TransportVehicle.StartJourney` branches on `transportType == Wagon` to decide trail-following vs. direct sailing, **ships currently try to follow land trails**. Fix during re-authoring.

### B3. What cannot come across

- The `.asset` YAML container format itself (`%YAML 1.1 / --- !u!114 &11400000 / MonoBehaviour:`) — Godot reads `.tres`, not this.
- `{fileID, guid, type}` reference triples — replaced by Godot resource paths or a string-ID registry.
- `Sprite` and `GameObject` field types (`ResourceData.resourceIcon`, `ColonyTypeData.prefab`, `TransportVehicleData.vehiclePrefab`) — retarget to `Texture2D` and `PackedScene`.
- `Color`, `Vector2Int` — Godot `Color` is compatible in concept; `Vector2Int` becomes `Vector2i`.
- `[CreateAssetMenu]`, `[Header]`, `[Tooltip]`, `[TextArea]`, `[Min]` — replaced by `[Export]`, `[ExportGroup]`, `[ExportRange]`, plus `@tool`/`class_name` registration.

### B4. Migration hazard: enum ordinals are baked into the data

`effectType` is stored as an integer. Decoding the current assets against `ResearchEffectType`:

| Asset | Stored `effectType` | Resolves to | Design doc intent |
|---|---|---|---|
| `Research_TradingPosts` | 17 | `Custom` | "UNLOCK AUTO-SELL TOGGLE" (`RESEARCH_TREE_DESIGN.md`, node `[4,0]`) — **mismatch** |
| `Research_TownCrier` | 17 | `Custom` | notifications |
| `Research_CensusRecords` | 17 | `Custom` | stats display |
| `Research_RecordKeeping` | 12 | `UnlockAutoSell` | — |
| `Research_TradeOffice` | 13 | `UnlockAutoSellTradeGoods` | — |
| `Research_FrontierSurveying` | 0 | `UnlockColonyType`, but `unlockedColonyType: {fileID: 0}` — **unassigned** | unlock Outpost |
| `Research_SettlementCharter` | 0 | `UnlockColonyType` → `ColonyType_Settlement` ✅ | unlock Settlement |
| `Research_ForestryManagement` / `Research_ForestryFocus` | 4 | `CategoryProductionBonus`, `affectedCategory: 2` = `Wood` ✅ | but no resource is tagged `Wood` (§B2) — no-op |

**Do not reorder `ResearchEffectType` or `ResourceCategory` before the conversion pass**, or every stored index silently re-points to a different effect.

---

## C. UNITY-COUPLED CODE — must be rewritten

30 MonoBehaviours + 4 Editor windows. Grouped by rewrite target.

### C1. Singleton managers → Godot autoloads

Pattern used throughout: `public static X Instance {get;private set;}` set in `Awake()`, with `if (Instance != null && Instance != this) { Destroy(gameObject); return; }`. In Godot these become **autoload singletons** (Project Settings → Autoload); the duplicate-destroy guard disappears entirely.

| Script | Unity coupling | Godot 4 target |
|---|---|---|
| `GameManager.cs` (42 L) | MonoBehaviour, `Awake`, `Transform mapParent`, `GameObject colonyPrefab`, `Debug.Log` | Autoload `Node`; `PackedScene` export |
| `ResourceManager.cs` (268 L) | MonoBehaviour, `Awake`/`Start`/`Update` timer, `[SerializeField]`, `Action<>` events, `Time.deltaTime` | Autoload `Node`; `_Process(double)` or a `Timer` node; `Action<>` → **`[Signal]` delegates** |
| `EconomyManager.cs` (154 L) | MonoBehaviour, `TextMeshProUGUI`, `UnityEngine.UI.Button`, coroutine `EnsureEconomyPanelActive`, `Invoke("UpdateUI", 0.2f)`, `Mathf.Pow` | Split: cost math → plain C# service; UI → `Control`; `Invoke` → `GetTree().CreateTimer(0.2).Timeout` + `await` |
| `IdleManager.cs` (112 L) | MonoBehaviour, `Update`, `PlayerPrefs`, `OnApplicationQuit`, `OnApplicationPause` | Autoload; `_Process`; `ConfigFile`/`FileAccess` save; `NOTIFICATION_WM_CLOSE_REQUEST` / `NOTIFICATION_APPLICATION_PAUSED` |
| `ColonyController.cs` (45 L) | MonoBehaviour registry + `Tick(dt)` fan-out | Autoload `Node`, or replace with a Godot **group** (`get_tree().call_group("colonies", ...)`) |
| `ResearchManager.cs` (496 L) | MonoBehaviour, `Awake`, `Action<>` events, `PlayerPrefs`, `Debug.Log` × ~25 | Autoload; `[Signal]`; `FileAccess` JSON save |
| `TransportManager.cs` (448 L) | MonoBehaviour, `Instantiate`, `Transform` parenting to a `RectTransform`, LINQ over vehicles | Autoload; `PackedScene.Instantiate()`; `AddChild` |
| `PrestigeManager.cs` (63 L) | MonoBehaviour, `SceneManager.LoadScene(activeScene.buildIndex)` for reset | Autoload; `GetTree().ReloadCurrentScene()` — **but see §E, this is currently orphaned** |
| `MapManager.cs` (521 L) | MonoBehaviour, `Texture2D`, `Color32`, `RawImage`, `RectTransform`, coroutine `DrawMapAsync`, `Mathf.PerlinNoise`, `Random.Range` | See §C5 |

### C2. Per-entity MonoBehaviours → Node scripts

| Script | Unity coupling | Godot 4 target |
|---|---|---|
| `ColonyProduction.cs` (212 L) | MonoBehaviour, `Awake`/`Start`/`OnDestroy`, `[Header]`/`[Min]`, `Vector2Int`, `event Action` | `Node2D` (or plain `Resource` + a view node); `_Ready`, `_ExitTree`; `[Export]`; `Vector2i`; `[Signal]`. **Logic core here is genuinely reusable** (§A2). |
| `ColonyView.cs` (134 L) | `UnityEngine.UI.Image`/`Button` added at runtime, `GetComponentInParent<Canvas>`, `EventSystem`, `raycastTarget` | `TextureButton` / `Button` inside a `Control`; wire `pressed` signal in the scene, not in code |
| `TransportVehicle.cs` (364 L) | MonoBehaviour, `Update`, `SpriteRenderer.flipX`, `transform.position`, `Mathf.SmoothStep`, `Mathf.Sin` bobbing, hardcoded `z = -10f` for sorting | `Node2D` + `Sprite2D`; `_Process(double)`; `Sprite2D.FlipH`; `Position`; `Tween` for the bob and for path traversal (**a `PathFollow2D` on a `Path2D` is a much better fit for trail following than the manual segment index in `UpdateJourney`**); z-hack → `ZIndex` / `YSortEnabled` |

### C3. uGUI / Canvas UI → Godot `Control` nodes

All of this is Canvas + `RectTransform` + TextMeshPro and none of it survives.

| Script | Unity coupling | Godot 4 target |
|---|---|---|
| `DashboardController.cs` (125 L) | `RectTransform.anchoredPosition`, `IEnumerator SlidePanel` coroutine + `Mathf.SmoothStep`, `SetActive` tab switching | `Control` + **`Tween`** (`TweenProperty` with `TRANS_CUBIC`); tabs → `TabContainer` |
| `ResourceTabManager.cs` (92 L) | `Instantiate(rowPrefab, container)`, `OnEnable`/`OnDisable` event sub/unsub | `PackedScene.Instantiate()` + `VBoxContainer`; `_Ready`/`VisibilityChanged`; Godot signals auto-disconnect on free |
| `ResourceRowView.cs` (91 L) | `Image`, `TextMeshProUGUI`, `Button`, `Toggle` | `TextureRect`, `Label`, `Button`, `CheckBox` |
| `RecipeTabManager.cs` (142 L) | same instantiate/subscribe pattern; ~15 `Debug.Log` calls per refresh | same as above; strip the logging |
| `RecipeRowView.cs` (90 L) | `Image`/`TMP`/`Button` | `TextureRect`/`Label`/`Button` |
| `ResearchTabManager.cs` (343 L) | `RectTransform.anchoredPosition`/`sizeDelta`, `gridContainer.localScale` zoom, runtime `GameObject` + `Image` connection lines rotated by `Quaternion.Euler` | `Control` graph. **Prefer `GraphEdit`, or a custom `Control` with `_Draw()` + `DrawLine`** over spawning rotated rectangle nodes. Zoom → `Node2D.Scale` / `Control` scale on a `SubViewport`. Scroll → `ScrollContainer` |
| `ResearchNodeView.cs` (166 L) | `Image`, `TMP`, `Button`, color-state swaps | `Button` with `Theme` variations / `StyleBox` states |
| `ColonyStorageUI.cs` (530 L) | Heavy: runtime `HorizontalLayoutGroup` construction, `TMP_Text` outlines via material props, manual object pooling, `Update()` polling on `Time.frameCount % 30` | `HBoxContainer`/`GridContainer` built in the scene editor; `LabelSettings` for outlines; drop pooling (Godot `Control` churn is cheaper); poll via a `Timer` node |
| `TradeMenuController.cs` (58 L) | `SetActive`, `AudioSource.PlayOneShot` | `Control.Visible`; `AudioStreamPlayer` — **but no audio files exist**, see §D |
| `NationalityButton.cs` (95 L) | `IPointerEnterHandler`, `AudioSource`, `CanvasGroup` fade coroutine, `FindAnyObjectByType<GameFlowController>()` | `Button` `mouse_entered` signal; `Modulate.A` via `Tween`; replace the type-search with an autoload reference |
| `GameFlowController.cs` (48 L) | `GameObject.SetActive` orchestration, `EventSystem.current.SetSelectedGameObject(null)` | State machine on a `Control`; `Visible`; `ReleaseFocus()` |
| `ButtonSinkEffect.cs` (58 L) | `IPointerDownHandler`/`IPointerUpHandler`, `localPosition` nudge | `Button` `button_down`/`button_up` signals + `Position` offset, or a pressed `StyleBox` |
| `UIWindowDragger.cs` (29 L) | `IDragHandler`, `eventData.delta`, `canvas.scaleFactor` | `_GuiInput` with `InputEventMouseMotion.Relative` |
| `UIMapZoomer.cs` (38 L) | `IScrollHandler`, `rectTransform.localScale` | `_GuiInput` + `MOUSE_BUTTON_WHEEL_UP/DOWN`, or `Camera2D.Zoom` |
| `MapCameraHandler.cs` (180 L) | **`UnityEngine.InputSystem`** (`Mouse.current.leftButton.wasPressedThisFrame`, `.scroll.ReadValue()`), `Camera.orthographicSize`, `ScreenToWorldPoint` | `Camera2D` + `Zoom`; `_UnhandledInput` with `InputEventMouseButton`/`InputEventMouseMotion`, or Godot's InputMap actions. **Currently unattached — see §E** |
| `DebugPanelLayout.cs` (65 L) | Diagnostic dump of `VerticalLayoutGroup`/`ContentSizeFitter` | **Do not port** (§E) |

### C4. Editor tooling → `@tool` scripts or a converter

All four use `UnityEditor`, `EditorWindow`, `MenuItem`, `AssetDatabase` — none of which exist in Godot.

| Script | Purpose | Godot 4 note |
|---|---|---|
| `Editor/ResourceGenerator.cs` (67 L) | `IdlePioneer/Generate 50 Resources` — bulk-creates the tier lists, then `SyncToSpawner()` | The **tier name lists at lines 14-18 are the authoritative resource taxonomy** and are worth keeping as migration input. An equivalent Godot `EditorPlugin` / `@tool` script could regenerate `.tres` |
| `Editor/TradeGoodGenerator.cs` (62 L) | `IdlePioneer/Generate 40 Trade Goods & Recipes` — title says 40, body only handles 10 basics | Same; the intended recipe pairings live here |
| `Editor/FontUpdater.cs` (64 L) | Bulk TMP font swap | Obsolete — Godot uses `Theme` resources |
| `Editor/RecipeRowPrefabValidator.cs` (119 L) | Validates prefab inspector wiring | Obsolete — the failure mode it guards against (unassigned inspector refs) is largely designed out by scene-local `%UniqueName` / `[Export]` in Godot |

### C5. Special case: `MapManager.cs` (521 L)

This one straddles B, C, and E and deserves its own note. Structure:

- **Generation** (`GenerateMap`, `AddOrganicIslands`, `IdentifyCoastAndShallows`) → algorithm portable (§A2), but `Mathf.PerlinNoise` → `FastNoiseLite` changes output.
- **Rendering** (`DrawMapAsync` coroutine, `Texture2D.SetPixels32`, `RawImage`) → Godot `Image` + `ImageTexture` + `TextureRect`; coroutine → `await ToSignal(GetTree(), "process_frame")` inside an `async` method, or a `Thread`.
  For a 2000 × 1500 grid the current approach materialises a 3-million-entry `Color32[]` and chunks 100k pixels/frame — **30 frames just to draw the map**. In Godot, prefer a `TileMapLayer` or a shader sampling a small data texture.
- **Coordinate transforms** (`GridToWorldPos`, `WorldToGridPos`) → pure math, portable; note the hardcoded 4000 × 3000 world extent.
- **Trail generation** (`CreateWagonTrail`, `FindValidTrailPoint`, `FindNearestLandTile`, `DrawTrailOnMap`, `DrawLineOnTexture`) → algorithms portable; Godot equivalent is generating a `Curve2D` and letting `PathFollow2D` walk it. Note `class WagonTrail` (bottom of file) is a plain serializable data holder — bucket A.
- **`CenterMapOn`** → couples to `RectTransform.anchoredPosition`; becomes `Camera2D.Position`.

---

## D. ART AND AUDIO ASSETS

### D1. Project art — imports directly (25 files)

All are plain rasters; Godot imports PNG/JPG natively.

**UI / theme** (`Assets/04_UI/`): `parchment_paper.png`, `DarkWood.png`, `HarborBackground.png`, `Sprite_Line.png`, `Image_Governors.png`
**Resource icons** (`Assets/04_UI/Resources/`): `Image_Timber.png`, `Image_Flax.png`, `Image_Corn.png`, `Image_Clay.png`, `Image_Research.png`, `Image_TradeGoods.png`, `Image_Motherland.png`, `ResourceButton.png`
**Colony icons** (`Assets/04_UI/ColonyTypes/`): `Image_Colony.png`, `Image_Outpost.png`
**Vehicles** (`Assets/04_UI/Animations/`): `image_Ship.png`, `image_Wagon.png`
**Research icons** (`Assets/04_UI/Research/`): `Image_CoastalNavigation.png`, `Image_TradingPosts.jpg`, `Path1/Image_FrontierSurveying.jpg`, `Path1/Image_LandGrants.png`, `Path2/Image_LoggingTechniques.png`, `Path2/Image_PrimitiveTools.png`

**Coverage is very thin:** 8 resource-ish icons against 50 resources + 10 trade goods; 5 research icons against 24 nodes; 2 colony icons against 5 colony types. Art is the largest content gap, independent of engine.

### D2. Fonts — import directly (2 project fonts)

`Assets/04_UI/Fonts/Almendra-Regular.ttf` and `ManufacturingConsent-Regular.ttf`. Godot loads TTF directly as `FontFile`.
The paired `*SDF.asset` files are **TextMeshPro font atlases** — Unity-proprietary, discard. Godot generates its own SDF via `FontFile.MultichannelSignedDistanceField`.

### D3. Audio — none exists

No `.wav`, `.mp3`, `.ogg`, or `.aiff` anywhere in `Assets/`. `NationalityButton.hoverSound`/`clickSound` (`NationalityButton.cs:9-10`) and `TradeMenuController.paperRustleSound` (`TradeMenuController.cs:9`) are **empty inspector slots**. There is no audio to port — only audio hooks to re-plan.

### D4. Unity-proprietary — does not carry meaning

| Item | Why it doesn't transfer |
|---|---|
| `Assets/04_UI/Animations/SellButton_Controller.controller` | Unity Animator state machine (states `Normal`/`Pressed`/`Disabled`). Godot: `AnimationPlayer`/`AnimationTree`, or just `Button` `StyleBox` states — the latter is the right call for a button. |
| `Assets/Shaders/RetroDither.shader` | ShaderLab + CG (`CGPROGRAM`, `#include "UnityCG.cginc"`). Properties (`_ColorDepth`, `_DitherStrength`, `_GrainAmount`) document intent — a retro dithered/grainy post look. Must be **rewritten in Godot Shading Language**; the intent is easy to re-express, the code is not portable. |
| 26 `.mat` + 15 `.shader` + 4 `.shadergraph` + 4 `.cginc` + 1 `.hlsl` under `Assets/TextMesh Pro/` | All TMP/URP internals. Discard wholesale. |
| `Assets/Settings/UniversalRP.asset`, `Renderer2D.asset`, `DefaultVolumeProfile.asset`, `Lit2DSceneTemplate.scenetemplate`, `04_UI/Fonts/UniversalRenderPipelineGlobalSettings.asset` | URP config. Godot has its own renderer settings; discard. |
| `Assets/InputSystem_Actions.inputactions` | **Unity's default template**, untouched — maps are `Player/Move,Look,Attack,Interact,Crouch,Jump,Sprint` and a UI map. Nothing game-specific. Discard; author a Godot InputMap fresh. |
| 6 `.psd`, plus all `.jpg`/`.png` under `Assets/TextMesh Pro/Examples & Extras/` | TMP sample content. Discard. |
| All `.meta` files | Unity guid bookkeeping. **Keep them readable during the conversion pass** (they resolve `{guid}` → path) then discard. |

---

## E. DEAD OR ABANDONED — do not port

Nothing here is deleted; this section only records what to leave behind.

### E1. Orphaned scripts — compiled but attached to nothing

Verified by grepping each script's `.meta` guid across all `.unity`, `.prefab`, and `.asset` files:

| Script | Status | Why exclude |
|---|---|---|
| `TradeManager.cs` | Not referenced | Self-declared: `[System.Obsolete]`, header says *"DEPRECATED … legacy wrapper for ResourceManager … DO NOT USE"* (`TradeManager.cs:4-10`). Superseded by `ResourceManager`. |
| `PrestigeManager.cs` | **Not referenced** | The prestige system exists as code but is **not in the scene** — nothing can call `DeclareIndependence()`. Also `CalculatePrestigeReward()` hardcodes `return 10` with a "for now" comment (`PrestigeManager.cs:47-52`), and `PerformReset()` reloads the scene as a "safest way" stopgap. **Port the *idea*, not this code** (Phase 2 §7). |
| `MapCameraHandler.cs` | **Not referenced** | 180-line world-space `Camera` controller, superseded by the UI-space `UIMapZoomer` + `UIWindowDragger` pair actually wired into `UIMap` in the scene. Evidence of an abandoned world-space-map approach. |
| `TradeMenuController.cs` | Not referenced | Panel toggler for a "trade menu" that isn't in the scene; audio slots empty. |
| `DebugPanelLayout.cs` | Not referenced | Self-declared *"Temporary debug script to diagnose Panel_Resources layout issues"* (`DebugPanelLayout.cs:4-6`). Pure Unity-layout diagnostics; meaningless in Godot. |

### E2. Abandoned map generation & spawning (per your brief — corroborated)

The generation/spawning code **runs**, but it is riddled with hardcoding, stopgaps, and abandoned branches. Recommend rewriting from the design intent rather than porting:

- `MapManager.GetMainlandCoast()` — comment: *"CRITICAL FIX: Islands spawn at shoreBuffer + 300 … Search only the left 60% of map to ensure starter colony spawns on mainland, NOT islands"*, with a 5000-attempt rejection-sampling loop and a `Debug.LogWarning` fallback. `GetRandomTileOfType()` is the same pattern with 2000 attempts and a silent `Vector2Int.zero` fallback. Both are brute-force placeholders.
- `MapManager.DrawMap()` — the sync version, explicitly annotated *"Legacy synchronous version (kept for reference or editor use)"*, dead alongside `DrawMapAsync`.
- `MapManager.GenerateMap()` — a hardcoded single north-south coastline (`bottomTarget = width*0.4f`, `topTarget = width*0.8f`) plus exactly `int islandSeeds = 4`. **No seed control, no biome/resource layer, no per-run variety knobs.** This does not deliver the "runs vary each time" goal.
- `ColonySpawner.GetResourcesForColony(int num)` — a hardcoded `switch` for colonies 1-4 with a `default: {"Timber"}` fallback. There is **no link between terrain and what a colony produces**; the land/water grid influences *placement only*. This is the biggest missing design piece.
- `ColonySpawner` **ignores `ColonyTypeData` entirely** — it uses one `colonyPrefab` field, never reads `productionMultiplier` or `storageCapacity`, and never consults `ResearchManager.IsColonyTypeUnlocked`. The whole colony-type ladder is unwired.
- `TransportManager.Update()` — the periodic collection sweep is fully commented out with *"Disabled: Each colony now has a dedicated transport vehicle that cycles automatically"*; `CheckColoniesForCollection()` and `SendVehicleToCollect()` are now unreachable dead paths kept in the file.
- `TransportVehicle.CanReachColony()` — `// TODO: Implement pathfinding/terrain checking`, currently a `distance < 20f` check against world units, in a coordinate space where colony distances are in the hundreds. Effectively always false for wagons.
- `GameManager.SpawnStarterColony()` — dead; `Start()` says *"Spawning logic moved to GameFlowController.StartGame"*.

### E3. Disabled / stubbed-out features

| Feature | Evidence |
|---|---|
| **Offline progress** | `IdleManager.LoadOfflineTime()`: *"TESTING FIX: Skipping … offline time to prevent freeze. TODO: Optimize bulk production calculation before enabling"* — any absence >10 s is discarded. `ProcessTick(int)` is private and never called. |
| **Research persistence** | `ResearchManager`: both `SaveResearchProgress()` and `LoadResearchProgress()` calls are commented out (`:59`, `:88`) — *"Research progress is NOT saved between sessions until prestige system is implemented"*. |
| **Research production bonuses** | `GetProductionMultiplier`, `GetColonyCostMultiplier`, `GetCraftingTimeMultiplier`, `GetCraftingOutputMultiplier`, `GetMaxCraftingSlots`, `IsAutoCraftUnlocked`, `IsAutoCollectUnlocked`, `IsAutoExpandUnlocked`, `IsRecipeUnlocked`, `IsColonyTypeUnlocked` — **zero callers outside `ResearchManager` itself**. Only `GetGoldSaleMultiplier`, `GetShipSpeedMultiplier`, `IsAutoSellUnlocked`, `IsAutoSellTradeGoodsUnlocked` are actually consumed. Paths 1, 2, 4, 5 of the research tree have no gameplay effect today. |
| **`GameConfigData`** | Defined, documented as *"replaces hardcoded magic numbers throughout the codebase"* — **no asset instance exists and no script references the type.** The magic numbers it was meant to replace are still hardcoded (`ColonyProduction.cs:113` `time *= 0.85f`; `ColonySpawner` `minimumShipDistance = 250f`; `EconomyManager` `baseColonyCost/costMultiplier`). |
| **Debug gold** | `ResourceManager.cs:14` `private double gold = 100; // TEST: Starts at 100 for testing. REVERT TO 0 FOR RELEASE.` plus a `Start()` re-forcing 100 if zero. |

### E4. Duplicate / stray assets

- `Assets/ColonyIcon.prefab` (repo root) vs `Assets/02_Prefabs/Colony_Icon.prefab` — only the latter carries `ColonyProduction` + `ColonyView`. The root one is a stray.
- `Assets/02_Prefabs/UI/ResourceRow.prefab` vs `Assets/02_Prefabs/ResourceRow_Prefab.prefab` — only the latter has a `ResourceRowView`; the former is an orphan.
- `Assets/02_Prefabs/RecipeRow_Prefab_Temp.prefab` — the `_Temp` suffix speaks for itself; it *is* the live prefab, which is why `Editor/RecipeRowPrefabValidator.cs` exists.
- Entire `Assets/TextMesh Pro/` tree (32 sample scenes, 24 sample scripts, 26 materials, ~15 textures) — vendor samples, never referenced by game code.
- `Assets/DOCS_GAME_DESIGN.md.txt` — a 13-line design brief with a `.md.txt` double extension. **Content is valuable** (quoted in Phase 2); the location is not.
- `Assets/Settings/Scenes/URP2DSceneTemplate.unity` — Unity template scene.

---

# PHASE 2 — Reconstructing the intended game

Tags: **CONFIRMED** = directly observed in code/data/docs · **INFERRED** = strongly implied by naming, structure, or partial implementation · **PROPOSED** = my recommendation, not evidence.

## 1. Identity and framing

**CONFIRMED.** Two names coexist. `Assets/DOCS_GAME_DESIGN.md.txt` heads with `# PROJECT: Colonial Frontiers (Mobile Idle)`, and `NationalityData.cs` uses `menuName = "Colonial Frontiers/Nationality Data"` — but every other SO uses `menuName = "IdlePioneer/..."` and the repo folder is `Idle Pioneer`. "Idle Pioneer" is the later name.

**CONFIRMED.** Target framing, verbatim from `DOCS_GAME_DESIGN.md.txt`:
> THEME: 17th Century Exploration (Parchment/Wood/Brass)
> - Passive Resource Generation at Colonies.
> - Automatic Transport Ships move goods to the "Hub" (Starter Colony).
> - Crafting/Selling only occurs at the Hub.
> - Prestige System: "Declare Independence" resets progress for Doubloons.

**CONFIRMED.** Mobile-first: `IdleManager.OnApplicationPause` handles backgrounding; `DrawMapAsync` is annotated *"prevent startup freeze on mobile"*; `ColonyStorageUI` object-pools rows.

## 2. The intended gameplay loop

**CONFIRMED** — from `GameFlowController.StartGame()`, `ColonySpawner`, `EconomyManager.OnFoundNewColony`:

1. **Choose a nationality** (`NationalityPanel`, 6 buttons) → sets a global modifier set → `GameFlowController.StartGame()` reveals map + HUD.
2. **A starter colony ("the Hub") is placed** on a mainland coast tile (`ColonySpawner.SpawnStarterColony` → `MapManager.GetMainlandCoast()`), and the camera centres on it.
3. **The Hub produces straight into central storage** (`useLocalStorage = false`), because `ColonySpawner.SpawnColony` sets `prod.useLocalStorage = !isStarter`.
4. **Sell resources for Gold** at the Hub (`ResourceRowView.OnSellClicked` → `ResourceManager.SellResource`).
5. **Spend Gold to found a new colony** at an exponentially rising price (`EconomyManager.nextColonyCost = 100 × 2.5^n`).
6. **Remote colonies accumulate into local storage** (`ColonyProduction.localInventory`) and **a dedicated vehicle is auto-spawned** to shuttle their output to the Hub (`ColonySpawner.SpawnTransportForColony` → `TransportManager.StartTransportCycle`).
7. **Craft raw materials into trade goods** at the Hub (`RecipeTabManager`, `RecipeData.Craft`), which sell for far more.
8. **Spend Gold + resources on research** to raise multipliers and unlock automation (`ResearchData.Research`).
9. **Eventually "Declare Independence"** for Doubloons and restart (see §7).

**INFERRED.** Steps 4-8 form the intended core idle loop; step 9 is the meta loop. **INFERRED**, from `RESEARCH_TREE_DESIGN.md` calling the 25-gold `Trading Posts` node *"FIRST research player should buy … makes the game much more playable"*: the arc is meant to run manual-click → auto-sell → auto-craft → auto-collect → auto-expand, i.e. the player automates themselves out of every step in order.

## 3. Currencies

**CONFIRMED.** Exactly two, both in `ResourceManager`:

- **Gold** (`double`) — the soft, in-run currency. Earned by selling; spent on colonies, research, vehicles. Standardising on `double` was a deliberate call (`IMPLEMENTATION_PLAN_REFACTOR.md`: *"Standardize all currency and resource values to `double` to prevent overflow in late-game incremental scaling"*).
- **Doubloons** (`int`) — the prestige currency. `RESEARCH_TREE_DESIGN.md:484`: *"No Doubloons (reserved for meta-progression system)"*.

**CONFIRMED.** A third currency was designed and abandoned: `NationalityData.libertyGenerationMultiplier` (Italian ×1.15) has no producer, consumer, or storage anywhere. "Liberty" is the *Colonization* mechanic that drives independence — its presence is the strongest single hint that the prestige gate was meant to be a Liberty threshold. **INFERRED.**

## 4. Resources and production chains

**CONFIRMED — resource flow:**

```
Colony (ColonyProduction, produces N resource types on a shared timer)
  ├─ Hub          → ResourceManager.AddResource (central inventory)  [useLocalStorage = false]
  └─ Remote colony → localInventory
                       ↓  TransportManager.CollectAndDepart — highest baseValue first, up to cargoCapacity
                     Wagon (land trail) / Ship (direct)
                       ↓  TransportVehicle.ArriveAtDestination
                     ResourceManager (central inventory at the Hub)
                       ├─ SellResource → Gold  (× research gold multiplier × category multiplier)
                       ├─ RecipeData.Craft → Trade Good → sell at much higher baseValue
                       └─ ResearchData.Research → consumed as research cost
```

**CONFIRMED — production formula as it exists today** (`ColonyProduction.TickProduction`):

```
modTime  = productionTime × (isDutch ? 0.85 : 1.0)        // Dutch check is dead (§B2)
cycles   = floor(accumulatedTime / modTime)
amount   = cycles × PrestigeManager.GetGlobalProductionMultiplier()   // = 1 + 0.1 × doubloons
```

Every produced resource in `producedResources` gets the *same* amount — a colony producing 3 resources yields 3× the total throughput of a single-resource colony, with no cost. **INFERRED** that this is an oversight rather than design.

**CONFIRMED — intended formula, per `ResearchManager.GetProductionMultiplier` (written, never called):**
`global × perResource × perCategory`, stacking multiplicatively. `RESEARCH_TREE_DESIGN.md` states this explicitly: *"Base 1.0 × Primitive Tools (1.15) × Logging (1.25) × Agricultural Focus (1.25) × Steam Power (2.0) = 3.59x total"*.

**PROPOSED** full multiplier chain for the rebuild, assembling every declared-but-unused input:
`base × colonyType.productionMultiplier × nationality.extractionRateMultiplier × research(global × resource × category) × (1 + 0.1 × doubloons)`

**CONFIRMED — the resource taxonomy is a 5-tier value ladder** (§B2), with tier ≈ rarity ≈ sell price, spanning 1 → 1000 gold. Trade goods sit above at a flat 50 (placeholder).

**CONFIRMED — production chains are two-deep and mostly unauthored.** Only 3 of 10 recipes have inputs, all of shape `2 raw → 1 refined` (Timber→Lumber, Clay→Bricks, Raw Hemp→Rope). **INFERRED** from `RESEARCH_TREE_DESIGN.md`'s costs (which demand Sails, Iron Tools, Woven Cloth, Simple Leather, Hard Bread in quantity) that the full set of 10 was always meant to be craftable and to feed research costs, not just gold.

**CONFIRMED — recipe discovery is inventory-driven, not research-driven.** `RecipeTabManager.RefreshDiscovery()`: a recipe becomes visible as soon as the player holds ≥1 unit of *any* one ingredient. `RESEARCH_TREE_DESIGN.md` confirms: *"Recipes unlock automatically as ingredients become available"*. That is a nice, low-friction discovery mechanic worth preserving. **PROPOSED: keep it.**

## 5. The land/water grid, colonies, and routes

**CONFIRMED — the data layer.** `MapManager` holds a flat `byte[] grid` of `gridWidth × gridHeight` = **2000 × 1500 = 3,000,000 cells**, each one of `TileType { DeepSea, ShallowSea, Land, Coast }`. It is built in three passes:

1. A meandering north-south shoreline: `baseline = Lerp(width×0.4, width×0.8, y/height)` plus two octaves of Perlin (`coastMeanderScale 0.001` ×400 amplitude, `coastWiggleScale 0.005` ×120). Everything west of the shore is `Land`, east is `DeepSea`.
2. `AddOrganicIslands` — 4 blobs seeded at least 300 cells east of the shoreline, radius 40-80, edges perturbed by `islandOrganicScale 0.05`.
3. `IdentifyCoastAndShallows` — `Land` adjacent to `DeepSea` becomes `Coast`; `DeepSea` within 2 cells of land becomes `ShallowSea`.

The grid is then rasterised straight to a `Texture2D` (land green `35,115,35`; coast sand `205,185,115`; shallow `50,100,160`; deep `15,30,80`) shown on a `RawImage`. `GridToWorldPos` maps the grid onto a 4000 × 3000 world rectangle.

**CONFIRMED — what the grid actually affects today:**

| Effect | Mechanism |
|---|---|
| Starter placement | must be a `Coast` tile in the left 35-60% of the map (`GetMainlandCoast`) |
| New colony placement | 60% chance `Land`, 40% chance `Coast` (`ColonySpawner.SpawnNewColony`) |
| Wagon vs. ship choice | `useShip = isWaterAccess && gridDistance >= 250` (`SpawnTransportForColony`) |
| Wagon route shape | `CreateWagonTrail` walks a Perlin-perturbed lerp and snaps every point back onto `Land`/`Coast` via `FindValidTrailPoint`/`FindNearestLandTile`; trails are cached in `wagonTrails` and **reused bidirectionally** by later vehicles (`GetTrailBetween`) and painted onto the map as brown 5px dirt roads |

**CONFIRMED — what the grid does *not* affect:** which resources a colony produces (that's the hardcoded `switch` in `ColonySpawner.GetResourcesForColony`), production rate, or storage.

**INFERRED — the intended design.** Coast being a distinct tile type from Land, plus ships being gated on water access, plus `TransportVehicle.CanReachColony`'s `// TODO: Implement pathfinding/terrain checking` and *"in future, check if coastal/has port"*, all point at: **coastal colonies can be served by ships (fast, high capacity: 200 vs 50), inland colonies must be served by wagons over generated land trails (slow, low capacity)**. Placement is therefore a real trade-off — inland sites are cheaper/more plentiful but logistically worse.

**PROPOSED — the missing half.** For "runs vary each time" to be meaningful, terrain must determine *yield*, not just access. Recommend a per-cell resource/biome layer generated alongside the land/water layer, so that the tier-5 goodies (Emeralds, Ambergris, Ancient Artifacts) are geographically scarce and each run's map genuinely reshapes the optimal build. This does not exist in any form today.

**PROPOSED.** Drop the 2000 × 1500 pixel-per-cell grid. It exists at that resolution only because the grid *is* the map texture. Decouple the simulation grid (a coarse `Vector2i` lattice, hundreds of cells) from the rendered map, which frees you from the 3M-element allocation and the 30-frame draw.

## 6. Trade, economy, and transport

**CONFIRMED — the economy is single-sink.** There is exactly one price for a resource (`ResourceData.baseValue`), no supply/demand, no market, no counterparty. `SellResource` mints gold from nothing. The "Motherland" panel in the scene (`Panel_Motherland`, `Btn_Motherland`, `Image_Motherland.png`) has **no script and no logic** — it is an empty tab.

**INFERRED.** Given the *Colonization* lineage and the Motherland tab + `Image_Governors.png` + `Panel_Governors` (also scriptless), the intended economy was richer than one flat sell price: selling *to the motherland* at fluctuating prices, and assigning **governors** to colonies for bonuses. `RESEARCH_TREE_DESIGN.md` node `[10,7] Governor System` confirms the latter: *"Unlock 'Governors' tab (future: assign governors to colonies for bonuses)"*. Both are stubs.

**CONFIRMED — the transport model is hub-and-spoke, one dedicated vehicle per colony.** No shared fleet pool, no multi-stop routes, despite `TransportManager.idleVehicles`/`FindAvailableVehicle` existing (leftovers from the abandoned pooled design, §E2). A vehicle loops: Hub → colony → load highest-value cargo to capacity → Hub → unload to `ResourceManager` → repeat.

**CONFIRMED — vehicle economics are defined but unreachable.** `TransportManager.PurchaseVehicle` implements gold + resource costs, and `TransportVehicleData.buildCosts` exists — but every vehicle in play is auto-spawned free by `ColonySpawner`, and `buildCosts` is `[]` on both assets. **INFERRED** the intent was that fleet expansion is a purchase decision, i.e. a second economic sink beside colonies.

**CONFIRMED.** Nationality bonuses map cleanly onto the economy's levers — ship speed (English), colony cost (French), sell price (Spanish), extraction rate (Dutch), wagon speed (Portuguese), liberty (Italian). Only the Spanish and English bonuses have live consumers, and even those go through `ResearchManager`, not `NationalityData` — **no code reads any `NationalityData` multiplier field at all.** The entire nationality system is decorative today.

## 7. Technology and progression

**CONFIRMED — structure.** A 6-path × 5-tier DAG, laid out on an explicit integer grid (`ResearchData.gridPosition`), paths spaced 2 columns apart (x = 0, 2, 4, 6, 8, 10), tier increasing down the y axis. Prerequisites are a `List<ResearchData>`, so it is a true DAG, not a chain. Node visibility is *disjunctive* (`IsVisible`: visible once **any one** prerequisite is done) while purchase is *conjunctive* (`CanResearch`: **all** prerequisites required) — a deliberate fog-of-war choice that shows players what's coming.

**CONFIRMED — the design target is 63 nodes** (`RESEARCH_TREE_DESIGN.md:474`) across Expansion(7), Extraction(8), Commerce(9), Crafting(10), Specialization(11), Governance(10), Synergy(6), Military(2). **24 exist as assets** (§B2). Costs run 25 → 15,000 gold, 5 tiers, with resource costs scaling from common (Timber, Corn) to exotic (Platinum, Diamonds).

**CONFIRMED — cross-path synergy nodes were designed** (e.g. `[9,3] Natural Philosophy` requires one node from Path 5 and one from Path 6, and multiplies *all other research bonuses*) explicitly to *"force diverse research"* and *"prevent single-path rushing"*. None are authored as assets. This is the most interesting unbuilt part of the tree.

**CONFIRMED — research is in-run, not permanent.** `ResearchManager.Start()`: *"Research progress is NOT saved between sessions until prestige system is implemented. Each playthrough starts fresh — research is temporary progression"*, and `ResetAllResearch()` exists for exactly that.

## 8. Prestige / rebirth structure

This is the clearest evidence of intended run structure. Assembling it:

**CONFIRMED:**
- `DOCS_GAME_DESIGN.md.txt`: *"Prestige System: 'Declare Independence' resets progress for Doubloons."*
- `PrestigeManager.DeclareIndependence()` → award Doubloons → `PerformReset()`.
- The reward is permanent and global: `GetGlobalProductionMultiplier() = 1 + 0.1 × doubloons`, consumed on every production tick (`ColonyProduction.cs:126-129`).
- `ResearchManager.ResetAllResearch()` exists and clears every bonus and unlock flag.
- `RESEARCH_SYSTEM_SETUP.md:200-208`: *"When the player prestiges (Declares Independence), call `ResearchManager.Instance.ResetAllResearch()`"*.
- Doubloons are deliberately excluded from the research tree's currency (`RESEARCH_TREE_DESIGN.md:484`).
- `RESEARCH_TREE_DESIGN.md` (Meta-Progression Synergy): *"Doubloons spent on permanent account-wide upgrades (separate from research). Examples: Start with more gold, faster initial production, unlock research faster. Research tree resets on prestige but permanent upgrades persist."*

**So the intended structure is a two-layer meta loop: in-run = Gold + research tree + colonies + map; permanent = Doubloons + a separate meta-upgrade tree.** That is fully consistent with the varying-map goal — a new map per run is what makes rebirth interesting rather than repetitive.

**CONFIRMED — but essentially unbuilt.** `PrestigeManager` is not in the scene (§E1), so nothing can trigger it. `CalculatePrestigeReward()` is `return 10;` with *"Later this can be based on lifetime gold or assets."* `PerformReset()` reloads the scene as an admitted stopgap. There is no Doubloon spending UI, no meta-upgrade tree, and no persistence of Doubloons across sessions.

**INFERRED — the intended prestige gate is Liberty.** `libertyGenerationMultiplier` on every nationality, plus the *Colonization*-derived name "Declare Independence", plus no other candidate resource, points at: colonies generate Liberty; accumulating enough Liberty enables Declaring Independence; the Doubloon payout scales with Liberty (or lifetime wealth). **No code produces or stores Liberty. This is the single largest designed-but-absent system in the repo.**

**INFERRED — map regeneration per run.** `MapManager.GenerateMap()` runs unconditionally in `Awake()` with no seed input, so a scene reload produces a new random map. That makes "new map per prestige" the *de facto* behaviour, though nothing records or reproduces a seed.

**PROPOSED for Session B:** make the run seed a first-class, saved value. Reproducible maps unlock daily challenges, shareable seeds, and debuggable balance — and they cost nothing to add now versus a lot to retrofit.

## 9. What the game actually is, in one paragraph

**INFERRED, synthesised.** *Idle Pioneer* is a mobile idle/incremental game wearing a 17th-century colonial coat. Each run generates a fresh coastline-and-islands map; you pick a colonial power, plant a Hub on the coast, and expand outward by buying colonies at exponentially rising prices. Colonies produce raw materials passively; geography decides whether a colony is served by a fast coastal ship or a slow overland wagon following a procedurally carved trail. Everything funnels to the Hub, where you sell for Gold and refine raws into far more valuable trade goods. Gold buys research across six parallel paths that first automate the tedium (auto-sell → auto-craft → auto-collect → auto-expand) and then multiply throughput, with cross-path synergy nodes rewarding breadth. When the colony is mature enough, you Declare Independence: the map, the colonies, and the research tree are wiped, and you keep Doubloons — a permanent production multiplier and the currency of a separate meta-upgrade layer — and start again on a new map.

## 10. Implementation maturity, honestly

| System | State |
|---|---|
| Resource inventory, gold, sell | **Working** |
| Colony production tick | **Working** (with the multi-resource duplication quirk) |
| Colony founding + exponential cost | **Working** |
| Map generation + rendering | **Working**, but hardcoded, unseeded, and expensive |
| Wagon trail generation & following | **Working** — the most polished single feature in the repo |
| Transport hub-and-spoke cycle | **Working** (ship/wagon tagging bug, §B2) |
| Auto-sell | **Working**, gated behind the wrong research nodes (§B4) |
| Crafting | **Partly working** — 7 of 10 recipes have no inputs |
| Research UI + purchase + prereqs | **Working** |
| Research *effects* | **4 of 18 effect types actually do anything** |
| Colony types | **Data only** — completely unwired |
| Nationalities | **Data only** — no multiplier is ever read |
| Prestige | **Code exists, not in the scene, not reachable** |
| Liberty | **Does not exist** |
| Save/load | **Does not exist** (three PlayerPrefs keys, two of them disabled) |
| Offline progress | **Deliberately disabled** |
| Governors, Motherland | **Empty UI panels** |
| Audio | **Does not exist** |

**The honest summary: the *data design* is considerably further along than the *implementation*.** For a Godot rebuild that is good news — the expensive creative work (a 50-resource ladder, a 63-node tree design, six nationalities, a colony-type curve, a working trail-generation algorithm) is documented and mostly extractable, while the code that must be thrown away is largely UI plumbing and Unity ceremony.

---

# OPEN QUESTIONS — answer these before Session B (architecture/planning)

1. **C# or GDScript?** Bucket A only pays off in C#. GDScript is faster to iterate, has better docs/community examples, and exports more simply — but throws away the ~15% of code that is directly portable and forces a rewrite of even the pure math. Which are you choosing, and is a mixed project (C# for simulation, GDScript for UI) acceptable?

2. **Automated `.asset` → `.tres` conversion, or manual re-authoring?** The YAML is machine-readable and the guid→path map is in the `.meta` files, so 93 assets could be converted by script. But ~40% of the data is placeholder or wrong (no resource categories, 7 empty recipes, blank nationality names, mis-tagged ship, unassigned colony type on Frontier Surveying). Do you want a converter that faithfully ports the flaws, a converter plus a manual fix-up pass, or a clean re-author using the old data purely as reference?

3. **Do you still want six nationalities?** Currently zero of their multipliers are read by any code. Keeping them means building the modifier plumbing that never existed. Is this a launch feature or a later one?

4. **Is Liberty in or out?** It's the missing prestige gate and the strongest tie to the *Colonization* inspiration, but it is 100% unbuilt. If it's in, what generates it — colonies, colony types, population, buildings? If it's out, what gates Declaring Independence — lifetime gold, colony count, a research node?

5. **Should terrain determine what a colony produces?** Today the land/water grid affects placement and transport mode only; production is a hardcoded `switch` on colony index. Adding a resource/biome layer is the change that would actually make runs vary meaningfully — but it's new design, not migration. In scope for the rebuild?

6. **Target scope for the research tree at first playable:** the 24 authored nodes, the 25-node "Phase 1" set from `RESEARCH_TREE_DESIGN.md`, or all 63? This drives how much of the effect-application layer must exist on day one.

7. **Is mobile still the target?** It shapes the input model (touch vs. mouse), the UI scaling strategy, the map rendering budget, and whether Godot's mobile renderer constraints matter. `MapCameraHandler` (desktop mouse/scroll) vs. `UIMapZoomer`+`UIWindowDragger` (UI-space) is exactly this unresolved question fossilised in the repo.

8. **Save architecture and run seeding.** There is nothing to inherit. Do you want a single JSON save with a recorded map seed (my recommendation — cheap now, expensive later), separate run vs. meta save files, and does offline progress need to work at launch given it was disabled for performance?

9. **Map representation.** Keep the 2000×1500 per-cell grid rendered as one big texture, or decouple a coarse simulation lattice from the visual map (`TileMapLayer` or a shader)? This decision constrains the trail system, pathfinding, and any future biome layer, so it should be made before anything is built.

10. **How much of the parchment/wood/brass art direction carries over?** 25 project images exist, covering roughly 8 of 60 resources and 5 of 24 research nodes, plus a Unity-only `RetroDither` shader. Are you re-arting, commissioning, or shipping with placeholder icons?
