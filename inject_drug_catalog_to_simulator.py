# -*- coding: utf-8 -*-
import json, re

with open('assets/drug_catalog.json', 'r', encoding='utf-8') as f:
    drug_list = json.load(f)

with open('simulator.html', 'r', encoding='utf-8') as f:
    sim = f.read()

# 1. Add CSS for Drug Catalog Modal & Doc View if not present
if '.catalog-modal-overlay' not in sim:
    catalog_css = '''
    /* 药品资料库选择弹层 */
    .catalog-modal-overlay {
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(12, 38, 28, 0.75);
      backdrop-filter: blur(6px);
      z-index: 130;
      display: none;
      align-items: flex-end;
      justify-content: center;
    }
    .catalog-modal-sheet {
      background: #ffffff;
      border-radius: 28px 28px 0 0;
      width: 100%;
      height: 82%;
      padding: 18px 20px 20px;
      box-shadow: 0 -12px 35px rgba(0,0,0,0.3);
      border-top: 2.5px solid #a7f3d0;
      display: flex;
      flex-direction: column;
      gap: 12px;
      animation: slideUp 0.28s ease-out;
    }
    .catalog-search-input {
      width: 100%;
      height: 44px;
      border: 2px solid #b7dfcc;
      border-radius: 12px;
      padding: 0 14px;
      font-size: 15px;
      font-weight: 700;
      color: #0c261c;
      background: #f8fbf9;
      outline: none;
    }
    .catalog-search-input:focus {
      border-color: #0d6b4f;
      background: #fff;
    }
    .catalog-cats-bar {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      padding-bottom: 4px;
    }
    .catalog-cat-chip {
      padding: 5px 12px;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 800;
      background: #e8f5f0;
      color: #2e4d3f;
      white-space: nowrap;
      cursor: pointer;
      user-select: none;
      transition: all 0.15s;
    }
    .catalog-cat-chip.active {
      background: #0d6b4f;
      color: #fff;
    }
    .catalog-list {
      flex: 1;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding-right: 2px;
    }
    .catalog-card-item {
      background: #f8faf9;
      border: 1.5px solid #d5e5db;
      border-radius: 16px;
      padding: 12px 14px;
      display: flex;
      flex-direction: column;
      gap: 4px;
      cursor: pointer;
      transition: all 0.15s;
    }
    .catalog-card-item:hover {
      border-color: #0d6b4f;
      background: #f0fdf4;
      transform: translateY(-1px);
    }

    /* 药品说明书详细弹窗 */
    .doc-modal-overlay {
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(12, 38, 28, 0.78);
      backdrop-filter: blur(6px);
      z-index: 140;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .doc-modal-card {
      background: #ffffff;
      border-radius: 26px;
      width: 100%;
      max-width: 350px;
      max-height: 82%;
      padding: 22px 20px;
      box-shadow: 0 20px 45px rgba(0,0,0,0.35);
      border: 2px solid #b7dfcc;
      display: flex;
      flex-direction: column;
      gap: 12px;
      overflow-y: auto;
      animation: popInGlow 0.3s ease-out;
    }
'''
    sim = sim.replace('</style>', catalog_css + '\n  </style>')

# 2. Add Catalog Modals HTML under phone-screen if not present
if 'id="drugCatalogModal"' not in sim:
    catalog_html = '''
      <!-- 【Excel 药品资料库选择弹窗】 -->
      <div class="catalog-modal-overlay" id="drugCatalogModal">
        <div class="catalog-modal-sheet">
          <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1.5px solid #edf4f0; padding-bottom: 8px;">
            <div style="font-size: 17px; font-weight: 900; color: #0c261c;">
              📚 选择药房滴眼液 <span style="font-size:12px; color:#059669; font-weight:bold;">(Excel 42条整理)</span>
            </div>
            <button class="btn btn-outline btn-xs" onclick="closeDrugCatalogModal()">关闭</button>
          </div>

          <!-- 快速搜索框 -->
          <input type="text" id="catalogSearchInput" class="catalog-search-input" placeholder="🔍 输入药名/品牌/适应症 (如：海露、典必殊)" oninput="filterCatalogList()">

          <!-- 分类筛选横滑栏 -->
          <div class="catalog-cats-bar" id="catalogCatsBar">
            <span class="catalog-cat-chip active" onclick="setCatalogCategory('全部')">全部 (38)</span>
            <span class="catalog-cat-chip" onclick="setCatalogCategory('干眼及润滑')">💧 干眼润滑 (7)</span>
            <span class="catalog-cat-chip" onclick="setCatalogCategory('抗菌')">🛡️ 抗菌 (7)</span>
            <span class="catalog-cat-chip" onclick="setCatalogCategory('抗炎')">🌿 抗炎 (5)</span>
            <span class="catalog-cat-chip" onclick="setCatalogCategory('降眼压')">🩺 降眼压 (8)</span>
            <span class="catalog-cat-chip" onclick="setCatalogCategory('散瞳／检查')">👁️ 散瞳检查 (6)</span>
            <span class="catalog-cat-chip" onclick="setCatalogCategory('修复／其他')">🌱 修复其他 (5)</span>
          </div>

          <!-- 药品卡片滚动列表 -->
          <div class="catalog-list" id="catalogListContainer"></div>

          <button class="btn btn-outline btn-xs" style="width:100%; height:38px; font-size:13px;" onclick="addCustomDrugPrompt()">
            ✍️ 未在资料库中找到？手动输入新药名
          </button>
        </div>
      </div>

      <!-- 【药品详细说明书弹窗】 -->
      <div class="doc-modal-overlay" id="drugDocModal">
        <div class="doc-modal-card">
          <div style="display: flex; justify-content: space-between; align-items: flex-start;">
            <div>
              <div style="font-size: 18px; font-weight: 900; color: #0c261c;" id="docModalName">妥布霉素滴眼液</div>
              <div style="display:flex; gap:6px; margin-top:4px;">
                <span class="badge" id="docModalCategory" style="background:#d1fae5; color:#065f46;">抗菌</span>
                <span style="font-size: 12px; color: #557566; font-weight:700;" id="docModalSpec">5ml:0.3%</span>
              </div>
            </div>
            <button class="btn btn-outline btn-xs" onclick="closeDrugDocModal()">关闭</button>
          </div>

          <div style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 14px; padding: 12px; font-size: 14px; color: #1e3a2b; line-height: 1.6;">
            <div style="font-weight: 900; color: #0d6b4f; margin-bottom: 2px;">【适应症（说明书摘要）】</div>
            <div id="docModalIndication">对激素敏感的眼部炎症，伴细菌感染或感染风险</div>
          </div>

          <div style="background: #f8faf9; border: 1px solid #d5e5db; border-radius: 14px; padding: 12px; font-size: 14px; color: #1e3a2b; line-height: 1.6;">
            <div style="font-weight: 900; color: #0d6b4f; margin-bottom: 2px;">【推荐用法用量（说明书摘要）】</div>
            <div id="docModalDosage">滴眼1～2滴，每4～6小时1次；用前充分摇匀。</div>
          </div>

          <div style="font-size: 13px; color: #557566; line-height: 1.6;">
            <div><strong>生产厂家：</strong> <span id="docModalMfr">s.a.ALCON-COUVREURn.v.</span></div>
            <div id="docModalLinkWrap" style="margin-top:4px;"></div>
          </div>

          <button class="btn btn-primary" style="width:100%; height:44px; font-size:15px; margin-top:4px;" onclick="closeDrugDocModal()">
            我知道了
          </button>
        </div>
      </div>
'''
    sim = sim.replace('<div class="wheel-modal-overlay" id="wheelPickerModal">', catalog_html + '\n      <div class="wheel-modal-overlay" id="wheelPickerModal">')

# 3. Build JS Catalog Code
drug_catalog_json_str = json.dumps(drug_list, ensure_ascii=False)

js_catalog_code = '// ==================== 官方 Excel 药品资料库 (38款眼科药房滴眼液) ====================\nconst DRUG_CATALOG = ' + drug_catalog_json_str + ';\n\n' + r'''
let activeCatalogCategory = '全部';

function openDrugCatalogModal() {
  document.getElementById('drugCatalogModal').style.display = 'flex';
  document.getElementById('catalogSearchInput').value = '';
  activeCatalogCategory = '全部';
  updateCatalogCategoryTabs();
  filterCatalogList();
}

function closeDrugCatalogModal() {
  document.getElementById('drugCatalogModal').style.display = 'none';
}

function setCatalogCategory(cat) {
  activeCatalogCategory = cat;
  updateCatalogCategoryTabs();
  filterCatalogList();
}

function updateCatalogCategoryTabs() {
  const chips = document.querySelectorAll('.catalog-cat-chip');
  chips.forEach(c => {
    if (c.innerText.includes(activeCatalogCategory)) c.classList.add('active');
    else c.classList.remove('active');
  });
}

function filterCatalogList() {
  const q = document.getElementById('catalogSearchInput').value.trim().toLowerCase();
  const container = document.getElementById('catalogListContainer');

  const filtered = DRUG_CATALOG.filter(d => {
    const matchCat = (activeCatalogCategory === '全部') || d.category.includes(activeCatalogCategory);
    const matchQ = !q || d.name.toLowerCase().includes(q) || d.generic_name.toLowerCase().includes(q) || d.brand_name.toLowerCase().includes(q) || d.indication.toLowerCase().includes(q);
    return matchCat && matchQ;
  });

  if (filtered.length === 0) {
    container.innerHTML = '<div style="color:#64748b; font-size:14px; text-align:center; padding:20px;">未检索到匹配的滴眼液，可尝试精简关键字。</div>';
    return;
  }

  container.innerHTML = filtered.map(d => `
    <div class="catalog-card-item" onclick="selectDrugFromCatalog(${d.id})">
      <div style="display:flex; justify-content:space-between; align-items:center;">
        <span style="font-size:16px; font-weight:900; color:#0c261c;">${d.name}</span>
        <span class="badge" style="background:#e8f5f0; color:#0d6b4f; font-size:11px;">${d.category}</span>
      </div>
      <div style="font-size:13px; color:#557566; font-weight:600;">
        规格：${d.spec} · ${d.manufacturer}
      </div>
      <div style="font-size:12px; color:#3d5a4c; line-height:1.4; margin-top:2px;">
        ${d.indication}
      </div>
    </div>
  `).join('');
}

function selectDrugFromCatalog(drugId) {
  const d = DRUG_CATALOG.find(x => x.id === drugId);
  if (!d) return;

  // 根据用法自动推荐频次
  let freq = '每日4次';
  let defaultTimes = ['08:00', '12:00', '16:00', '20:00'];
  if (d.dosage.includes('每日2次') || d.dosage.includes('每12小时')) {
    freq = '每日2次';
    defaultTimes = ['08:00', '20:00'];
  } else if (d.dosage.includes('每日3次')) {
    freq = '每日3次';
    defaultTimes = ['08:00', '14:00', '20:00'];
  } else if (d.dosage.includes('每日1次') || d.dosage.includes('睡前')) {
    freq = '每日1次';
    defaultTimes = ['20:00'];
  } else if (d.dosage.includes('每日5') || d.dosage.includes('每日6')) {
    freq = '每日5次';
    defaultTimes = ['08:00', '11:00', '14:00', '17:00', '20:00'];
  }

  state.draftMedications.push({
    name: d.name,
    eye: '双眼',
    frequency: freq,
    dose: '每次1滴',
    days: 14,
    times: defaultTimes
  });

  closeDrugCatalogModal();
  showToast(`已添加【${d.name}】至用药计划！`);
  render();
}

function addCustomDrugPrompt() {
  const name = prompt('请输入新药品名称：', '妥布霉素滴眼液');
  if (!name) return;
  state.draftMedications.push({
    name: name.trim(),
    eye: '双眼',
    frequency: '每日4次',
    dose: '每次1滴',
    days: 14,
    times: ['08:00', '12:00', '16:00', '20:00']
  });
  closeDrugCatalogModal();
  render();
}

// 查找药品说明书
function findDrugInCatalog(name) {
  if (!name) return null;
  const clean = name.replace(/[（\(][^）\)]+[）\)]/g, '').trim();
  for (const d of DRUG_CATALOG) {
    if (d.name === name) return d;
    if (d.generic_name === clean || d.generic_name === name) return d;
    if (d.brand_name && (name.includes(d.brand_name) || d.name.includes(name))) return d;
    if (name.includes(d.generic_name) || d.generic_name.includes(name)) return d;
  }
  return null;
}

function showDrugDoc(name) {
  const d = findDrugInCatalog(name);
  if (!d) {
    alert(`【${name}】\n\n暂未在药房资料库中找到精确记录，请核对随附说明书并遵医嘱使用。`);
    return;
  }

  document.getElementById('docModalName').innerText = d.name;
  document.getElementById('docModalCategory').innerText = d.category;
  document.getElementById('docModalSpec').innerText = d.spec;
  document.getElementById('docModalIndication').innerText = d.indication;
  document.getElementById('docModalDosage').innerText = d.dosage;
  document.getElementById('docModalMfr').innerText = d.manufacturer || '详见药盒';

  const linkWrap = document.getElementById('docModalLinkWrap');
  if (d.manual_url && d.manual_url !== 'NaN' && d.manual_url !== '') {
    linkWrap.innerHTML = `<a href="${d.manual_url}" target="_blank" style="color:#0d6b4f; font-weight:800; text-decoration:underline;">🔗 查看说明书及权威资料来源 ›</a>`;
  } else {
    linkWrap.innerHTML = '';
  }

  document.getElementById('drugDocModal').style.display = 'flex';
}

function closeDrugDocModal() {
  document.getElementById('drugDocModal').style.display = 'none';
}
'''

# 4. Replace DRUG_DOCS and showDrugDoc in one go
idx1 = sim.find('const DRUG_DOCS')
idx2 = sim.find('// ==================== 7.')
if idx1 != -1 and idx2 != -1:
    sim = sim[:idx1] + js_catalog_code + '\n\n' + sim[idx2:]
    print("Replaced old DRUG_DOCS and showDrugDoc successfully.")
else:
    print(f"WARNING: idx1={idx1}, idx2={idx2}")

# 5. In renderPlanTab: replace onclick="addNewMedication()" with openDrugCatalogModal()
sim = sim.replace('onclick="addNewMedication()"', 'onclick="openDrugCatalogModal()"')

with open('simulator.html', 'w', encoding='utf-8') as f:
    f.write(sim)

print("simulator.html updated with 38-drug Excel catalog!")
