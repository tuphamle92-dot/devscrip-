// tools/package-spiderman.cjs - Package Spider-Man Ped Mods into GTA V Legacy DLC RPF
const fs = require('fs');
const path = require('path');
const { RpfWriter } = require('./rpf-builder.cjs');

const PED_DIR = 'D:/Telegram/ped';
const OUT_DIR = 'D:/Telegram/spiderman';
const OUT_RPF = path.join(OUT_DIR, 'dlc.rpf');

if (!fs.existsSync(PED_DIR)) {
  console.error('Không tìm thấy thư mục:', PED_DIR);
  process.exit(1);
}

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

console.log('[Spider-Man DLC] Bắt đầu đóng gói...');

// 1. Build nested child RPF: spiderman_peds.rpf
const nestedWriter = new RpfWriter();
const pedFiles = fs.readdirSync(PED_DIR);
let count = 0;
for (const f of pedFiles) {
  const fpath = path.join(PED_DIR, f);
  if (fs.statSync(fpath).isFile()) {
    const buf = fs.readFileSync(fpath);
    nestedWriter.addFile(f, buf);
    count++;
  }
}
console.log(`[Spider-Man DLC] Đã thêm ${count} tệp tài nguyên vào spiderman_peds.rpf`);
const nestedRpfBuf = nestedWriter.build();
console.log(`[Spider-Man DLC] spiderman_peds.rpf kích thước: ${(nestedRpfBuf.length / (1024*1024)).toFixed(2)} MB`);

// 2. Prepare XML metadata
const setup2Xml = `<?xml version="1.0" encoding="utf-8"?>
<SSetupData>
	<deviceName>dlc_spiderman</deviceName>
	<datFile>content.xml</datFile>
	<timeStamp>10/14/2026 12:00:00 PM</timeStamp>
	<nameHash>spiderman</nameHash>
	<contentChangeSetGroups>
		<Item>
			<NameHash>GROUP_STARTUP</NameHash>
			<ContentChangeSets>
				<Item>spiderman_AUTOGEN</Item>
			</ContentChangeSets>
		</Item>
	</contentChangeSetGroups>
	<type>EXTRACONTENT_COMPAT_PACK</type>
	<order value="10" />
</SSetupData>
`;

const contentXml = `<?xml version="1.0" encoding="utf-8"?>
<CDataFileMgr__ContentsOfDataFileXml>
	<disabledFiles />
	<includedXmlFiles />
	<includedDataFiles />
	<dataFiles>
		<Item>
			<filename>dlc_spiderman:/common/data/peds.meta</filename>
			<fileType>PED_METADATA_FILE</fileType>
			<locked value="false" />
			<disabled value="true" />
			<persistent value="true" />
			<overlay value="true" />
		</Item>
		<Item>
			<filename>dlc_spiderman:/%PLATFORM%/models/cdimages/spiderman_peds.rpf</filename>
			<fileType>RPF_FILE</fileType>
			<locked value="false" />
			<disabled value="true" />
			<persistent value="true" />
			<overlay value="true" />
		</Item>
	</dataFiles>
	<contentChangeSets>
		<Item>
			<changeSetName>spiderman_AUTOGEN</changeSetName>
			<filesToEnable>
				<Item>dlc_spiderman:/common/data/peds.meta</Item>
				<Item>dlc_spiderman:/%PLATFORM%/models/cdimages/spiderman_peds.rpf</Item>
			</filesToEnable>
		</Item>
	</contentChangeSets>
	<patchFiles />
</CDataFileMgr__ContentsOfDataFileXml>
`;

const pedsMeta = `<?xml version="1.0" encoding="utf-8"?>
<CPedModelInfo__InitDataList>
	<InitDatas>
		<Item>
			<Name>spiderman_advanced_suit_ps4</Name>
			<ModelName>spiderman_advanced_suit_ps4</ModelName>
			<PropsName />
			<ClipDictionaryName>move_m@generic</ClipDictionaryName>
			<BlendShapeFileName />
			<ExpressionSetName>exprSet_male</ExpressionSetName>
			<ExpressionDictionaryName />
			<ExpressionName />
			<Pedtype>CIVMALE</Pedtype>
			<MovementClipSet>move_m@generic</MovementClipSet>
			<StrafeClipSet>move_ped_strafing</StrafeClipSet>
			<MovementToStrafeClipSet>move_ped_to_strafe</MovementToStrafeClipSet>
			<InjuredStrafeClipSet>move_strafe_injured</InjuredStrafeClipSet>
			<DefaultVisemeClipSet />
			<FastTeleportClipSet />
			<PedCapsuleName>standard_male</PedCapsuleName>
			<PedLayout />
			<PedComponentClothName />
			<Age value="0" />
			<Sex>Male</Sex>
			<MaxHealth value="200" />
			<Accuracy value="60" />
		</Item>
		<Item>
			<Name>ironspider_infinitywar</Name>
			<ModelName>ironspider_infinitywar</ModelName>
			<PropsName />
			<ClipDictionaryName>move_m@generic</ClipDictionaryName>
			<BlendShapeFileName />
			<ExpressionSetName>exprSet_male</ExpressionSetName>
			<ExpressionDictionaryName />
			<ExpressionName />
			<Pedtype>CIVMALE</Pedtype>
			<MovementClipSet>move_m@generic</MovementClipSet>
			<StrafeClipSet>move_ped_strafing</StrafeClipSet>
			<MovementToStrafeClipSet>move_ped_to_strafe</MovementToStrafeClipSet>
			<InjuredStrafeClipSet>move_strafe_injured</InjuredStrafeClipSet>
			<DefaultVisemeClipSet />
			<FastTeleportClipSet />
			<PedCapsuleName>standard_male</PedCapsuleName>
			<PedLayout />
			<PedComponentClothName />
			<Age value="0" />
			<Sex>Male</Sex>
			<MaxHealth value="200" />
			<Accuracy value="60" />
		</Item>
		<Item>
			<Name>2017_SMHC</Name>
			<ModelName>2017_SMHC</ModelName>
			<PropsName />
			<ClipDictionaryName>move_m@generic</ClipDictionaryName>
			<BlendShapeFileName />
			<ExpressionSetName>exprSet_male</ExpressionSetName>
			<ExpressionDictionaryName />
			<ExpressionName />
			<Pedtype>CIVMALE</Pedtype>
			<MovementClipSet>move_m@generic</MovementClipSet>
			<StrafeClipSet>move_ped_strafing</StrafeClipSet>
			<MovementToStrafeClipSet>move_ped_to_strafe</MovementToStrafeClipSet>
			<InjuredStrafeClipSet>move_strafe_injured</InjuredStrafeClipSet>
			<DefaultVisemeClipSet />
			<FastTeleportClipSet />
			<PedCapsuleName>standard_male</PedCapsuleName>
			<PedLayout />
			<PedComponentClothName />
			<Age value="0" />
			<Sex>Male</Sex>
			<MaxHealth value="200" />
			<Accuracy value="60" />
		</Item>
		<Item>
			<Name>2019_FFH</Name>
			<ModelName>2019_FFH</ModelName>
			<PropsName />
			<ClipDictionaryName>move_m@generic</ClipDictionaryName>
			<BlendShapeFileName />
			<ExpressionSetName>exprSet_male</ExpressionSetName>
			<ExpressionDictionaryName />
			<ExpressionName />
			<Pedtype>CIVMALE</Pedtype>
			<MovementClipSet>move_m@generic</MovementClipSet>
			<StrafeClipSet>move_ped_strafing</StrafeClipSet>
			<MovementToStrafeClipSet>move_ped_to_strafe</MovementToStrafeClipSet>
			<InjuredStrafeClipSet>move_strafe_injured</InjuredStrafeClipSet>
			<DefaultVisemeClipSet />
			<FastTeleportClipSet />
			<PedCapsuleName>standard_male</PedCapsuleName>
			<PedLayout />
			<PedComponentClothName />
			<Age value="0" />
			<Sex>Male</Sex>
			<MaxHealth value="200" />
			<Accuracy value="60" />
		</Item>
	</InitDatas>
</CPedModelInfo__InitDataList>
`;

// 3. Build main dlc.rpf
const rootWriter = new RpfWriter();
rootWriter.addFile('setup2.xml', Buffer.from(setup2Xml, 'utf8'));
rootWriter.addFile('content.xml', Buffer.from(contentXml, 'utf8'));
rootWriter.addFile('common/data/peds.meta', Buffer.from(pedsMeta, 'utf8'));
rootWriter.addFile('x64/models/cdimages/spiderman_peds.rpf', nestedRpfBuf);

const dlcRpfBuf = rootWriter.build();
fs.writeFileSync(OUT_RPF, dlcRpfBuf);

console.log(`[Spider-Man DLC] Đóng gói THÀNH CÔNG!`);
console.log(`[Spider-Man DLC] Đường dẫn: ${OUT_RPF}`);
console.log(`[Spider-Man DLC] Dung lượng: ${(dlcRpfBuf.length / (1024*1024)).toFixed(2)} MB`);
