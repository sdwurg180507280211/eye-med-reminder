# -*- coding: utf-8 -*-
raw_data = """序号,药品名称（原表）,规格（原表）,用途分类,适应症（说明书摘要）,推荐用法用量（说明书摘要）,完整药瓶照片,照片说明／匹配状态,查看照片来源,查看说明书／资料,生产厂家（原表）,原表行号
1,盐酸奥布卡因滴眼液（倍诺喜）,0.5ml*10支 0.4%,散瞳／检查,眼科操作所需的眼表表面麻醉。,一般成人滴眼1～4滴，可按年龄、体质调整；仅由眼科医务人员用于检查或操作，单剂量使用后弃余液。,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,NaN,参天制药（中国）有限公司,3
2,氧氟沙星滴眼液,5ml:15mg,抗菌,敏感细菌所致结膜炎、角膜炎等外眼部感染,滴眼；一般1滴，每日3次，疗程按感染情况决定；核对武汉五景制剂说明书。,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,待核原说明书,武汉五景药业有限公司,4
3,妥布霉素地塞米松滴眼液（典必殊眼液）,5ml：15mg：5mg*1支,抗菌,对激素敏感的眼部炎症，伴细菌感染或感染风险,滴眼1～2滴，每4～6小时1次；初期可每2小时1次，改善后减量；用前摇匀。,暂缺完整药瓶照片,药瓶图待补,NaN,NaN,s.a.ALCON-COUVREURn.v.,5
4,妥布霉素滴眼液（托百士眼液）,5ml:0.3%,抗菌,敏感细菌所致外眼及附属器感染,轻、中度：患眼1～2滴，每4小时1次；重度：每小时2滴，改善后减量。,查看照片链接,网络同款预览（联网）,NaN,NaN,s.a.ALCON-COUVREURn.v.,6
5,聚乙二醇滴眼液(思然）,10ml/支/盒（每ml：聚乙二醇4mg；丙二醇3mg）,干眼及润滑,暂时缓解干眼引起的眼部干涩、烧灼及刺激感,按需滴入患眼1～2滴；原表10ml包装的说明书需进一步核对。,暂缺完整药瓶照片,药瓶图待补,NaN,待核原说明书,ALconLaboratories，inc。,7
6,玻璃酸钠滴眼液（海露0.1%）,0.1%，10ml,干眼及润滑,用于干眼症，缓解干眼症状。,每次1滴，每日3次；必要时可增加次数，若每日超过10次须咨询眼科医生。,实物照片,已嵌入原图（瓶+盒）,NaN,NaN,德国URSAPHARMARZNEIMITTELGMBH,8
7,左氧氟沙星滴眼液（可乐必妥）0.5%,5ml：24.4mg,抗菌,敏感细菌引起的细菌性结膜炎、角膜炎等眼部感染,滴眼1滴，每日3次；疗程及年龄限制核对可乐必妥0.5%说明书。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,上药控股有限公司,9
8,氟米龙滴眼液,5ml：5mg,抗炎,对糖皮质激素敏感的结膜、角膜、眼前段炎症,滴眼1～2滴，每日2～4次；按炎症程度调整；混悬液用前摇匀。,查看照片链接,网络同款预览（联网）,NaN,NaN,参天制药（中国）有限公司,10、11
9,玻璃酸钠滴眼液（爱丽）,5ml:15mg（0.3%）*1支,干眼及润滑,干眼综合征及手术、药物、外伤等造成的角结膜上皮损伤。,每次1滴，每日5～6次，可随症状调整。,查看照片链接,网络同款预览（联网）,NaN,NaN,参天制药（中国）有限公司,12
10,硝酸毛果芸香碱滴眼液（真瑞）,5ml:25mg,降眼压,多种类型青光眼降眼压，以及散瞳后的缩瞳,慢性青光眼常用0.5%制剂每次1滴，每日1～4次；急性发作依眼科急救方案。,查看照片链接,网络同款预览（联网）,NaN,NaN,山东博士伦福瑞达制药有限公司,13
11,马来酸噻吗洛尔滴眼液,25mg:5ml,降眼压,开角型青光眼及高眼压症的眼压控制,滴眼1滴，每日2次；须排查哮喘、心动过缓等禁忌。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,山东博士伦福瑞达制药有限公司,14
12,醋酸泼尼松龙滴眼液（百力特）,5ml:50mg,抗炎,眼前段对糖皮质激素有反应的非感染性眼部炎症,滴眼1～2滴，每日2～4次；严重炎症起始可增加频次，逐步减量；用前摇匀。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,重庆医药集团药特分有限责任公司,15、16
13,普拉洛芬滴眼液（普南扑灵）,5ml：5mg,抗炎,眼睑炎、结膜炎、角膜炎、术后炎症等外眼和眼前段炎症。,通常每次1～2滴，每日4次；根据症状调整，具体核对普南扑灵说明书。,查看照片链接,网络同款预览（联网）,NaN,NaN,日本Senju Pharmaceutical Co Ltd Pukusaki,17
14,盐酸氮卓斯汀滴眼液（6ml）,0.05%6ml,抗过敏,缓解过敏性结膜炎引起的眼痒。,每眼1滴，每日2次。,查看照片链接,网络同款预览（联网）,NaN,NaN,重庆九州通物流有限公司,18
15,盐酸氮卓斯汀滴眼液（10ml）,0.05%（10ml：5mg）,抗过敏,缓解过敏性结膜炎引起的眼痒。,每眼1滴，每日2次。,暂缺完整药瓶照片,药瓶图待补,NaN,NaN,德国URSAPHARMARZNEIMITTELGMBH,19
16,复方托吡卡胺滴眼液,(5ml:25mg:25mg)*1ml,散瞳／检查,检查用散瞳及睫状肌麻痹。,散瞳检查：滴眼1滴，5分钟后再滴1滴；屈光检查方案须按眼科流程。【注意：原表规格“5ml×1ml”文字矛盾，需按实物核对。】,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,NaN,沈阳兴齐眼药股份有限公司,20
17,盐酸卡替洛尔滴眼液,2% 5ml：100mg,降眼压,青光眼和高眼压症的眼压控制,滴眼1滴，每日2次；需监测眼压，排查心肺禁忌。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,中国大冢制药有限公司,21
18,盐酸莫西沙星滴眼液,0.5%（0.6ml：3mg）,抗菌,敏感细菌所致眼部细菌性感染,滴眼1滴，每日3次；如为术后预防或不同适应证须核实说明书。【原厂家原规格说明书待复核。】,暂缺完整药瓶照片,药瓶图待补,NaN,待核原说明书,北京汇恩兰德制药有限公司,22
19,玻璃酸钠滴眼液0.3%(欧沁）,0.3%(0.8ml:2.4mg)*5支*4袋,干眼及润滑,干眼综合征和术后等所致的角结膜上皮损伤,滴眼1滴，每日5～6次；按症状增减；单剂量包装用后丢弃。,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,NaN,北京汇恩兰德制药有限公司,23
20,加替沙星滴眼液0.3%5ml,0.3%5ml,抗菌,敏感细菌导致的细菌性结膜炎等感染,滴眼1滴，每日3次；通常按疗程使用，核对本厂家0.3%说明书。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,中国大冢制药有限公司,24
21,双氯芬酸钠滴眼液（含玻璃酸钠）,5ml;5mg,抗炎,眼科手术相关炎症、非感染性眼前段炎症及疼痛,滴眼1滴，每日4次；手术前后方案按相应说明书。【原厂家原规格说明书待复核。】,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,待核原说明书,珠海联邦制药股份有限公司,25
22,人表皮生长因子滴眼液（易贝）,40000IU(80ug)/4ml,修复／其他,角膜上皮损伤修复辅助治疗,滴眼1～2滴，每日4次；具体以易贝说明书及损伤程度为准。【原厂家原规格说明书待复核。】,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,待核原说明书,桂林华诺威基因药业有限公司,26
23,布林佐胺滴眼液（派立明）,5ml：50mg(1%),降眼压,开角型青光眼及高眼压症降低眼压。,患眼1滴，每日2次；部分患者可每日3次；混悬液用前摇匀。,暂缺完整药瓶照片,药瓶图待补,NaN,NaN,s.a.ALCON-COUVREURn.v.,63
24,玻璃酸钠滴眼液(海露0.2%）,0.2%（10ml：20mg）,干眼及润滑,中重度及持久性干眼症眼球表面润滑，缓解干眼症状。,每次1滴，每日3次；需要时可增加频率。,查看照片链接,网络同款预览（联网）,NaN,NaN,宁波瑞霖医药有限公司,81
25,布林佐胺噻吗洛尔滴眼液（派立噻）,5ml：50mg：25mg/支,降眼压,开角型青光眼或高眼压症的眼压控制,滴眼1滴，每日2次；使用前摇匀，注意β受体阻滞剂禁忌。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,比利时Novartis Manufacturing,82、83
26,酒石酸溴莫尼定滴眼液,0.15% 5ml/支,降眼压,开角型青光眼和高眼压症的眼压控制,滴眼1滴，每日3次（约间隔8小时）；核对0.15%剂型说明书。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,美国ALLERGAN SALES LLC,85
27,拉坦噻吗滴眼液（适利加）,2.5ml,降眼压,β受体阻滞剂效果不足的开角型青光眼、高眼压症,患眼1滴，每日1次；不应超过每眼每日1滴。,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,NaN,Pfizer Manufacturing Beglium NV,86
28,硫酸阿托品滴眼液,0.01%（0.4ml：0.04mg）*15支*2包,修复／其他,延缓符合批准适应症条件的儿童近视进展。,通常每眼1滴，每日1次，宜睡前用；年龄、屈光条件及治疗方案请核对兴齐说明书。,查看照片链接,网络同款预览（联网）,NaN,NaN,沈阳兴齐眼药股份有限公司,89
29,普拉洛芬滴眼液,0.1%（5ml:5mg）,抗炎,眼睑炎、结膜炎、角膜炎、虹膜睫状体炎、术后炎症等。,每次1～2滴，每日4次；按症状增减。,查看照片链接,网络同款预览（联网）,NaN,NaN,山东海山药业有限公司,95
30,曲伏前列素滴眼液（苏为坦）,2.5ml:0.1mg,降眼压,开角型青光眼及高眼压症的降眼压治疗,每眼1滴，每日1次，通常晚间；超量不会增加降眼压疗效。,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,待核原说明书,"西班牙SIEGFRIED EIMASNOU,S,A,",96
31,双氯芬酸钠滴眼液,0.4ml*20支,抗炎,眼科手术相关炎症、非感染性眼部炎症及疼痛,滴眼1滴，每日4次；单剂量包装一次性使用；核对具体说明书。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,重庆医药集团药特分有限制责任公司,97
32,托吡卡胺滴眼液,6ml：30mg,散瞳／检查,眼科散瞳及睫状肌麻痹检查,眼部检查前由医护滴眼，通常1～2滴；实际频次按检查流程。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,山东博士伦福瑞达制药有限公司,98
33,盐酸丙美卡因滴眼液（爱尔凯因）,15ml:75mg,散瞳／检查,测眼压、去除角膜异物等眼科表面麻醉,短时操作前1～2滴；小手术每5～10分钟1～2滴，共1～3次；仅医护操作。,查看照片链接,网络同款预览（联网）,NaN,NaN,ALconLaboratories，inc。,99
34,盐酸环喷托酯滴眼液,15ml,散瞳／检查,散瞳与睫状肌麻痹，用于眼科检查。,成人每眼1滴，必要时5分钟后重复；儿童每眼1滴，必要时10分钟后重复；医护操作。,查看照片链接,网络同款预览（联网）,NaN,NaN,Alcon  NV,100
35,左氧氟沙星滴眼液（汇明）,5ml：24.4mg,抗菌,敏感细菌引起的细菌性结膜炎和角膜炎,滴眼1滴，每日3次；疗程及儿童用法按汇明说明书核对。,查看照片链接,网络同款预览（联网）,NaN,待核原说明书,北京汇恩兰德制药有限公司,102、103
36,七叶洋地黄双苷滴眼液,0.4ml*10支,修复／其他,眼底黄斑变性，以及眼肌性、神经性、适应性眼疲劳,每眼1滴，每日3次；眼疲劳改善后可每日2次。,查看照片链接,网络同款预览（联网）,NaN,NaN,德国视都灵药品有限责任公司,104
37,全氟己基辛烷滴眼液,3ml,干眼及润滑,睑板腺功能障碍（MGD）相关干眼。,每眼每次1滴，每日4次。,查看照片链接,网络同款预览（联网）,NaN,NaN,成都盛迪医药有限公司,105
38,利非司特滴眼液,5%(0.2ml:10mg)*5支*6袋,干眼及润滑,治疗干眼病的体征及症状。,每眼1滴，每日2次（间隔约12小时），单剂量容器使用后丢弃。,暂缺完整药瓶照片,仅有外盒图，药瓶待补,NaN,NaN,成都普什制药有限公司,106"""

raw_links = """序号,药品名称,规格,图片直链（Microsoft 365预览）,图片出处网页／检索链接,药品说明书及适应症来源,图片核验说明,用法信息状态,源表行号
1,盐酸奥布卡因滴眼液（倍诺喜）,0.5ml*10支 0.4%,https://s.315jiage.cn/upload/2026-04/26041813482761.jpg,https://www.315jiage.cn/n422159,https://www.liangjian11.com/Product?pcode=951924,仅外盒,已取得相关说明书/药学资料,3
2,氧氟沙星滴眼液,5ml:15mg,https://drug-platform.cdn.bcebos.com/online/drug/18b0d547219811efbbc8fa2600039d34.jpg,https://health.baidu.com/malls/goods/db2c_164060294452114340_384088016065593344,,仅外盒,待核厂家具体规格,4
3,妥布霉素地塞米松滴眼液（典必殊眼液）,5ml：15mg：5mg*1支,,https://www.bing.com/images/search?q=%E5%A6%A5%E5%B8%83%E9%9C%89%E7%B4%A0%E5%9C%B0%E5%A1%9E%E7%B1%B3%E6%9D%BE%E6%BB%B4%E7%9C%BC%E6%B6%B2%EF%BC%88%E5%85%B8%E5%BF%85%E6%AE%8A%E7%9C%BC%E6%B6%B2%EF%BC%89%205ml%EF%BC%9A15mg%EF%BC%9A5mg%2A1%E6%94%AF%20s.a.ALCON-COUVREURn.v.%20%E5%AE%8C%E6%95%B4%E8%8D%AF%E7%93%B6%20%E5%A4%96%E7%9B%92,https://www.iophthal.com/index/drug/detail?id=68,未找到可核对的完整瓶照,已取得相关说明书/药学资料,5
4,妥布霉素滴眼液（托百士眼液）,5ml:0.3%,https://img0.miaoshoucdn.com/ueditor/php/upload/image/20180603/1527992511862144.jpg,https://www.miaoshou.com/product/3737.html,https://www.iophthal.com/index/drug/detail?id=4,瓶+盒；品牌规格匹配,已取得相关说明书/药学资料,6
5,聚乙二醇滴眼液(思然）,10ml/支/盒（每ml：聚乙二醇4mg；丙二醇3mg）,,https://www.bing.com/images/search?q=%E8%81%9A%E4%B9%99%E4%BA%8C%E9%86%87%E6%BB%B4%E7%9C%BC%E6%B6%B2%28%E6%80%9D%E7%84%B6%EF%BC%89%2010ml/%E6%94%AF/%E7%9B%92%EF%BC%88%E6%AF%8Fml%EF%BC%9A%E8%81%9A%E4%B9%99%E4%BA%8C%E9%86%874mg%EF%BC%9B%E4%B8%99%E4%BA%8C%E9%86%873mg%EF%BC%89%20ALconLaboratories%EF%BC%8Cinc%E3%80%82%20%E5%AE%8C%E6%95%B4%E8%8D%AF%E7%93%B6%20%E5%A4%96%E7%9B%92,,未找到可核对的完整瓶照,待核厂家具体规格,7
6,玻璃酸钠滴眼液（海露0.1%）,0.1%，10ml,,用户上传实物照片,https://ypk.39.net/2034318/manual/,用户提供的瓶+盒；已离线嵌入,已取得相关说明书/药学资料,8
7,左氧氟沙星滴眼液（可乐必妥）0.5%,5ml：24.4mg,https://i.ebayimg.com/images/g/PjsAAOSw7Y1nStMX/s-l1200.jpg,https://www.ebay.com.au/itm/387669615924,,瓶+盒；品牌规格匹配,待核厂家具体规格,9
8,氟米龙滴眼液,5ml：5mg,https://file.fh21static.com/fhfile1/M00/64/13/ooYBAGJp8lGAGYhVAAKcKlKhaB4068.jpg,https://www.fh21.com/drug/22220097/instructions.html,https://www.dayi.org.cn/drug/1156350?from=sll,瓶+盒；规格匹配,待核厂家具体规格,10、11
9,玻璃酸钠滴眼液（爱丽）,5ml:15mg（0.3%）*1支,https://file.fh21static.com/fhfile1/M00/64/4F/oYYBAGJp_e6AZSCxAAGpWMMotac640.jpg,https://www.fh21.com/drug/22222962/effect.html,https://ypsm.yzsbh.com/drugFilter.action?interId=Y00000012568&show_navbar=true,瓶+盒；0.3%规格匹配,已取得相关说明书/药学资料,12
10,硝酸毛果芸香碱滴眼液（真瑞）,5ml:25mg,https://s.315jiage.cn/upload/2023-08/23080311026505.jpg,https://www.315jiage.cn/mn84261.aspx,https://ypk.39.net/585319/manual/,瓶+盒；规格厂家匹配,已取得相关说明书/药学资料,13
11,马来酸噻吗洛尔滴眼液,25mg:5ml,https://img0.miaoshoucdn.com/product/watermark/6/93/693b4fadbfc0a16b5caedfc45fd1854b.jpg,https://www.miaoshou.com/product/177048.html,,瓶+盒；规格厂家匹配,待核厂家具体规格,14
12,醋酸泼尼松龙滴眼液（百力特）,5ml:50mg,https://file.fh21static.com/fhfile1/M00/64/4B/o4YBAGJp_L-AGqQAAAG2kU36f24386.jpg,https://www.fh21.com/news/gdv61x67xq.html,,瓶+盒；规格品牌匹配,待核厂家具体规格,15、16
13,普拉洛芬滴眼液（普南扑灵）,5ml：5mg,https://drug-platform.cdn.bcebos.com/online/drug/d1694516838468677770.png,https://health.baidu.com/malls/goods/db2c_163282748670850800_248858874806525952,https://www.315jiage.cn/n135975,瓶+盒；规格厂家匹配,已取得相关说明书/药学资料,17
14,盐酸氮卓斯汀滴眼液（6ml）,0.05%6ml,https://image.jianke.com/mall/product/201909/5d5efd37dcb745338722d82a420f8182.jpg,https://www.jianke.com/product/158538.html,https://www.315jiage.cn/n607255,瓶+盒；6ml相同，原表厂家仅为经销商,已取得相关说明书/药学资料,18
15,盐酸氮卓斯汀滴眼液（10ml）,0.05%（10ml：5mg）,,https://www.bing.com/images/search?q=%E7%9B%90%E9%85%B8%E6%B0%AE%E5%8D%93%E6%96%AF%E6%B1%80%E6%BB%B4%E7%9C%BC%E6%B6%B2%EF%BC%8810ml%EF%BC%89%200.05%25%EF%BC%8810ml%EF%BC%9A5mg%EF%BC%89%20%E5%BE%B7%E5%9B%BDURSAPHARMARZNEIMITTELGMBH%20%E5%AE%8C%E6%95%B4%E8%8D%AF%E7%93%B6%20%E5%A4%96%E7%9B%92,https://www.315jiage.cn/n607255,未找到可核对的完整瓶照,已取得相关说明书/药学资料,19
16,复方托吡卡胺滴眼液,(5ml:25mg:25mg)*1ml,,https://www.315jiage.cn/n133691,https://ypk.39.net/2006217/manual,原厂家外盒/实物待核,已取得相关说明书/药学资料,20
17,盐酸卡替洛尔滴眼液,2% 5ml：100mg,https://pimg.39.net/yaopin/20190902/04/2019090215_65110_496586.jpg,https://ypk.39.net/496586/tuji/,,瓶+盒；2%同规格厂家,待核厂家具体规格,21
18,盐酸莫西沙星滴眼液,0.5%（0.6ml：3mg）,,https://www.bing.com/images/search?q=%E7%9B%90%E9%85%B8%E8%8E%AB%E8%A5%BF%E6%B2%99%E6%98%9F%E6%BB%B4%E7%9C%BC%E6%B6%B2%200.5%25%EF%BC%880.6ml%EF%BC%9A3mg%EF%BC%89%20%E5%8C%97%E4%BA%AC%E6%B1%87%E6%81%A9%E5%85%B0%E5%BE%B7%E5%88%B6%E8%8D%AF%E6%9C%89%E9%99%90%E5%85%AC%E5%8F%B8%20%E5%AE%8C%E6%95%B4%E8%8D%AF%E7%93%B6%20%E5%A4%96%E7%9B%92,,未找到可核对的完整瓶照,待核厂家具体规格,22
19,玻璃酸钠滴眼液0.3%(欧沁）,0.3%(0.8ml:2.4mg)*5支*4袋,https://image.jianke.com/mall/product/202303/9451d2ba659442e099f014802d06fd17.jpg,https://www.jianke.com/product/881921.html,https://www.huonland.com/upload/attachment/202312/26/040426/%E7%8E%BB%E7%92%83%E9%85%B8%E9%92%A0%E6%BB%B4%E7%9C%BC%E6%B6%B2.pdf,仅外盒；包装支数可能不同,已取得相关说明书/药学资料,23
20,加替沙星滴眼液0.3%5ml,0.3%5ml,https://drug-platform.cdn.bcebos.com/online/drug/d1646105512371609995.png,https://health.baidu.com/malls/goods/db2c_163282748670850800_413361035686428672,,瓶+盒；同规格厂家,待核厂家具体规格,24
21,双氯芬酸钠滴眼液（含玻璃酸钠）,5ml;5mg,https://file.fh21static.com/fhfile1/M00/37/4F/ooYBAGIPX2SAbmtkAAJIVAMM7Tg096.jpg,https://www.fh21.com/news/oqr7lzyood.html,,仅外盒,待核厂家具体规格,25
22,人表皮生长因子滴眼液（易贝）,40000IU(80ug)/4ml,https://pimg.39.net/yaopin/20190903/05/2019090303_2342052_620723.jpg,https://ypk.39.net/620723/tuji/,,仅外盒,待核厂家具体规格,26
23,布林佐胺滴眼液（派立明）,5ml：50mg(1%),,https://www.bing.com/images/search?q=%E5%B8%83%E6%9E%97%E4%BD%90%E8%83%BA%E6%BB%B4%E7%9C%BC%E6%B6%B2%EF%BC%88%E6%B4%BE%E7%AB%8B%E6%98%8E%EF%BC%89%205ml%EF%BC%9A50mg%281%25%29%20s.a.ALCON-COUVREURn.v.%20%E5%AE%8C%E6%95%B4%E8%8D%AF%E7%93%B6%20%E5%A4%96%E7%9B%92,https://ypk.39.net/2029565/manual/,未找到可核对的完整瓶照,已取得相关说明书/药学资料,63
24,玻璃酸钠滴眼液(海露0.2%）,0.2%（10ml：20mg）,https://pimg.39.net/PictureLib/A/f80/c9/20250826/org/1960263314571395083.jpg,https://ypk.39.net/2310591/,https://ypk.39.net/2310591/manual/,瓶+盒；0.2%规格匹配,已取得相关说明书/药学资料,81
25,布林佐胺噻吗洛尔滴眼液（派立噻）,5ml：50mg：25mg/支,https://drug-platform.cdn.bcebos.com/online/drug/b4723c94f2a611efa3e1fa28000db461.jpg,https://health.baidu.com/malls/goods/db2c_165113176683630936_1054963041574141952,,完整药瓶；品牌规格匹配,待核厂家具体规格,82、83
26,酒石酸溴莫尼定滴眼液,0.15% 5ml/支,https://img.360yao.com/upload/ware/20220530/1653910120913.jpg,https://www.360yao.com/product/358870.html,,瓶+盒；规格品牌匹配,待核厂家具体规格,85
27,拉坦噻吗滴眼液（适利加）,2.5ml,https://www.nbdyf.com/yaopinmulu/UploadPhotos/202109/2021092615182550.png,https://www.nbdyf.com/yaopinmulu/2721.html,https://www.viatris.com.cn/-/media/project/viatris-sites/product-document/20eyedrops.pdf,仅外盒,已取得相关说明书/药学资料,86
28,硫酸阿托品滴眼液,0.01%（0.4ml：0.04mg）*15支*2包,https://file.bohe.cn/fhfile1/M00/27/EF/oYYBAGf8fGeAWqVMAAcIiDjIFhE180.png,https://yao.bohe.cn/drug/22257321/instructions.html,https://yao.bohe.cn/drug/22257321/instructions.html,完整单剂量支+盒；规格匹配,已取得相关说明书/药学资料,89
29,普拉洛芬滴眼液,0.1%（5ml:5mg）,https://drug-platform.cdn.bcebos.com/online/drug/d1695021400999454713.png,https://health.baidu.com/malls/goods/db2c_161588178152369652_217551535335923712,https://www.315jiage.cn/n135975,瓶+盒；厂家规格匹配,已取得相关说明书/药学资料,95
30,曲伏前列素滴眼液（苏为坦）,2.5ml:0.1mg,https://img.360bzl.com/images/202107/goods_img/4252_P_1626653127021.jpg,https://www.360bzl.com/goods-4252.html,,仅外盒,待核厂家具体规格,96
31,双氯芬酸钠滴眼液,0.4ml*20支,https://2dhall-pic.ciftis.org/image/20210817/882572075c8d478c9ca3421d654c1c1d.jpg,https://2d.ciftis.org/view/productmgr/productdetail?productId=46742,,单剂量支+盒；规格匹配，原表厂家疑似经销商,待核厂家具体规格,97
32,托吡卡胺滴眼液,6ml：30mg,https://s.315jiage.cn/upload/2023-09/23093015298567.jpg,https://www.315jiage.cn/n136397,,瓶+盒；厂家规格匹配,待核厂家具体规格,98
33,盐酸丙美卡因滴眼液（爱尔凯因）,15ml:75mg,https://www.mountainside-medical.com/cdn/shop/files/Alcaine-Eye-Drops-Proparacaine-hydrochloride_700x700.jpg?v=1746022791,https://www.mountainside-medical.com/products/alcaine-eye-drops-proparacaine-hydrochloride-0-5,https://swin.zy91.com/pages/m-instruction/m.instruction.html?hospitalCode=1&webHisId=32301,完整瓶+盒；海外版包装，国内实物待核,已取得相关说明书/药学资料,99
34,盐酸环喷托酯滴眼液,15ml,https://ailaaj.pk/cdn/shop/files/AC-31-Cyclogyl-1.png?v=1718297550&width=1445,https://ailaaj.pk/products/cyclogyl-eye-drops-1-15ml,https://www.315jiage.cn/n87628,完整瓶+盒；海外版包装，国内实物待核,已取得相关说明书/药学资料,100
35,左氧氟沙星滴眼液（汇明）,5ml：24.4mg,https://rl.lonwin.net/images/uploadify/20230506/724d15b5-47aa-475e-8419-e11fe84f81c8.jpg,https://rl.lonwin.net/product-detail.aspx?cid=25&id=10013,,瓶+盒；汇明规格匹配,待核厂家具体规格,102、103
36,七叶洋地黄双苷滴眼液,0.4ml*10支,https://image.360lj.com/watermark/prodimage/202011/2020113134422315.jpg,https://www.liangjian11.com/Product?pcode=723196,https://www.taixinhospital.com/yycx1/content_2866,单剂量支+盒；规格匹配,已取得相关说明书/药学资料,104
37,全氟己基辛烷滴眼液,3ml,https://www.market-scope.com/files/uploads/images/2025/07/Heng%20Qin%20package.jpg,https://www.market-scope.com/pages/news/8501/chinese-regulators-approve-perfluorohexyloctane-drops-for-dry-eye-with-mgd,https://www.hnysfww.com/goods.php?id=13936,瓶+盒；3ml规格匹配,已取得相关说明书/药学资料,105
38,利非司特滴眼液,5%(0.2ml:10mg)*5支*6袋,https://www.cnkh.com/upload/images/2026/05/20/7e9b281cd1ad4dde844690d0804d51dd.jpg,https://www.cnkh.com/productnew/17649.htm,https://www.cnkh.com/productnew/17649.htm,仅外盒,已取得相关说明书/药学资料,106"""

import csv, io, json, re

# Parse Table 1
f1 = io.StringIO(raw_data)
reader1 = csv.reader(f1)
header1 = next(reader1)

drugs = {}
for row in reader1:
    if not row or not row[0].isdigit():
        continue
    idx = int(row[0])
    name = row[1].strip()
    spec = row[2].strip()
    category = row[3].strip()
    indication = row[4].strip()
    dosage = row[5].strip()
    manufacturer = row[10].strip() if len(row) > 10 else ''
    
    # Extract generic name and brand name
    # e.g. 妥布霉素地塞米松滴眼液（典必殊眼液）
    brand_match = re.search(r'[（\(]([^）\)]+)[）\)]', name)
    brand = brand_match.group(1) if brand_match else ''
    generic = re.sub(r'[（\(][^）\)]+[）\)]', '', name).strip()

    drugs[idx] = {
        "id": idx,
        "name": name,
        "generic_name": generic,
        "brand_name": brand,
        "spec": spec,
        "category": category,
        "indication": indication,
        "dosage": dosage,
        "manufacturer": manufacturer,
        "image_url": "",
        "source_url": "",
        "manual_url": ""
    }

# Parse Table 2 (Links)
f2 = io.StringIO(raw_links)
reader2 = csv.reader(f2)
header2 = next(reader2)

for row in reader2:
    if not row or not row[0].isdigit():
        continue
    idx = int(row[0])
    if idx in drugs:
        drugs[idx]["image_url"] = row[3].strip() if len(row) > 3 else ""
        drugs[idx]["source_url"] = row[4].strip() if len(row) > 4 else ""
        drugs[idx]["manual_url"] = row[5].strip() if len(row) > 5 else ""

drug_list = list(drugs.values())

with open(r'd:\Desk\Google Gravity\assets\drug_catalog.json', 'w', encoding='utf-8') as f:
    json.dump(drug_list, f, ensure_ascii=False, indent=2)

print(f"Successfully generated assets/drug_catalog.json with {len(drug_list)} drugs!")
