# ⚡ Steal a Power (اسرق القوة)

لعبة روبلوكس: تدوّر على قوى نادرة، تقاتل فيها، وإذا طيّحت أحد **تسرق قوته**.

## شو موجود بهذه النسخة

| النظام | التفاصيل |
|---|---|
| اللفّات | 11 قوة بستة مستويات ندرة، من Common (50%) إلى Secret (0.1%)، مع أنيميشن للّفة |
| القتال | لكمة دايماً معك، وقوة وحدة تلبسها. فيها مقذوفات وصواعق ونيازك وسحب وتجميد ودفع |
| السرقة | إذا طيّحت أحد، قوته اللابسها تطيح كرة. القاتل له أول 3 ثواني ليمسكها، وبعدها أي أحد. إذا ما مسكها أحد خلال 15 ثانية ترجع لصاحبها |
| المطلوب (Bounty) | 5 قتلات ورا بعض بدون ما تموت = تصير مطلوب: تلمع أحمر من ورا الجدران، وضربك أقوى 20%، واللي يطيّحك ياخذ 500 كوين |
| الدمج | 3 نسخ من نفس القوة = نجمة (+15% ضرر)، لحد 5 نجوم |
| الأمان | منطقة آمنة بالنص ما فيها ضرر، وحماية 3 ثواني بعد الرسبون، وتبديل القوى بس داخل المنطقة الآمنة |
| ضد الغش | السيرفر يتحقق من كل ضربة: الكولداون، المسافة، إنك تملك القوة. واللي يطلع من اللعبة وسط القتال يخسر قوته |
| الحفظ | DataStore: الكوينز والقوى والنجوم والقتلات |
| دمى تدريب | 4 دمى جنب المنطقة الآمنة تجرب عليها قواك لحالك |
| الخريطة والواجهة | الخريطة كاملة والواجهة كاملة تنبني من الكود، فما تحتاج تسوي شي بإيدك |
| الأجهزة | كمبيوتر وموبايل وكنترولر |

## التركيب بالنسخ واللصق (10 دقائق)

1. افتح **Roblox Studio** واختر **New** ثم **Baseplate**.
2. من **File** اختر **Publish to Roblox**. لازم تنشر اللعبة عشان الحفظ يشتغل.
3. من **Home** افتح **Game Settings** ثم **Security**، وفعّل **Enable Studio Access to API Services**، واضغط **Save**.
4. سوّ هذه السكربتات. **الاسم والنوع لازم يكونون بالضبط مثل الجدول:**

| المكان في Explorer | النوع | الاسم | انسخ الكود من |
|---|---|---|---|
| ReplicatedStorage | ModuleScript | `PowerConfig` | `src/shared/PowerConfig.lua` |
| ServerScriptService | Script | `Main` | `src/server/Main.server.lua` |
| ServerScriptService | ModuleScript | `DataService` | `src/server/DataService.lua` |
| ServerScriptService | ModuleScript | `MapBuilder` | `src/server/MapBuilder.lua` |
| ServerScriptService | ModuleScript | `PowerService` | `src/server/PowerService.lua` |
| ServerScriptService | ModuleScript | `CombatService` | `src/server/CombatService.lua` |
| ServerScriptService | ModuleScript | `Abilities` | `src/server/Abilities.lua` |
| ServerScriptService | ModuleScript | `StealService` | `src/server/StealService.lua` |
| ServerScriptService | ModuleScript | `DummyService` | `src/server/DummyService.lua` |
| StarterPlayer ← StarterPlayerScripts | LocalScript | `ClientMain` | `src/client/ClientMain.client.lua` |
| StarterPlayer ← StarterPlayerScripts | ModuleScript | `UI` | `src/client/UI.lua` |

   **كيف تسوي سكربت:** وقّف على المكان في Explorer واضغط **+**، واختر النوع، وغيّر الاسم بـ **F2**، وبعدين امسح الكود اللي فيه والصق كود الملف.

5. اضغط **Play** ▶️

**تبي تجرب القتال بين لاعبين؟** من **Test** اختر **Clients and Servers** و **2 Players** واضغط **Start**.

> إذا طلعت لك رسالة "Saving is OFF" فالحفظ مطفي. ارجع للخطوتين 2 و 3.

## التحكم

| | كمبيوتر | موبايل | كنترولر |
|---|---|---|---|
| لكمة | كليك أو F | زر PUNCH | X |
| القوة | E | زر POWER | R2 |
| التصويب | الماوس | نص الشاشة | نص الشاشة |

## تعديل اللعبة

كل أرقام اللعبة في **`PowerConfig`**: سعر اللفة، النسب، الضرر، الكولداون، الكوينز... غيّر الرقم واضغط Play.

### إضافة قوة جديدة

أضف هذا داخل `PowerConfig.PowerList`:

```lua
{
	Id = "PoisonDart",
	Name = "Poison Dart",
	Rarity = "Rare",
	Kind = "Projectile",
	Damage = 12,
	Cooldown = 1,
	Range = 160,
	Speed = 180,
	Size = 0.8,
	Color = Color3.fromRGB(80, 255, 80),
	Burn = { Damage = 4, Ticks = 4 },
	Description = "A fast dart that poisons.",
},
```

`Kind` يحدد شو تسوي القوة: `Projectile` أو `Strike` أو `Pull` أو `Push` أو `Freeze` أو `Storm`. الشرح فوق القائمة في `PowerConfig`.
لو نسيت حقل، اللعبة توقف وتقول لك بالضبط شو الناقص في نافذة **Output**.

## كيف الكود مرتب

| الملف | شو يسوي |
|---|---|
| `PowerConfig` | كل الأرقام والقوى. السيرفر والكلاينت يقرون منه |
| `Main` | يشغّل كل شي ويربط طلبات اللاعب بالأنظمة |
| `DataService` | الحفظ والتحميل، وكل تغيير على بيانات اللاعب |
| `PowerService` | اللفّة والتلبيس والدمج |
| `CombatService` | يتحقق من كل ضربة، والضرر، والدفع، والتجميد |
| `Abilities` | شو تسوي كل قوة، والمؤثرات |
| `StealService` | الكرة اللي تطيح، والسرقة، ونظام المطلوب |
| `DummyService` | دمى التدريب |
| `MapBuilder` | يبني الخريطة |
| `ClientMain` | التحكم والتصويب، والتواصل مع السيرفر |
| `UI` | كل الواجهة |

**القاعدة الذهبية:** الكلاينت بس يقول "ضغطت E وأنا أصوّب هنا". السيرفر هو اللي يقرر هل مسموح وكم الضرر، فما أحد يقدر يغش ويرسل "اضرب 9999".

## الطريقة الاحترافية: Rojo

إذا تبي تكتب الكود في VS Code بدل الستوديو: ثبّت [Rojo](https://rojo.space)، وشغّل `rojo serve` داخل هذا المجلد، وبعدين وصّل من إضافة Rojo داخل الستوديو. ملف `default.project.json` جاهز ويحط كل سكربت بمكانه.

## اختبار النسب

```sh
sh tests/run.sh
```

يحتاج [Luau CLI](https://github.com/luau-lang/luau/releases). يسوي مليون لفّة ويتأكد إن النسب صحيحة، ويفحص حساب الضرر والمنطقة الآمنة.

## الخطوات الجاية

1. **Game Pass "حظ x2":** `PowerConfig.RollPower` يقبل `luck` من الحين.
2. **Developer Product:** لفّات تنشرى بالروبوكس.
3. **خانة قوة ثانية** وضربات كومبو.
4. **التداول** بين اللاعبين.
5. **مطر النيازك:** حدث كل ساعة يطيّح قوى Secret بالخريطة.
6. **أصوات وأنيميشن** للضربات.
