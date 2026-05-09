import SwiftUI

enum AppTab: Hashable {
    case home
    case tracks
    case equipment
    case profile
}

struct MainTabView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var selectedTab: AppTab = .home
    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem {
                        VStack(spacing: 2) {
                            Image(systemName: "house")
                            Text("首页")
                        }
                    }
                    .tag(AppTab.home)

                TrackHubView()
                    .tabItem {
                        VStack(spacing: 2) {
                            Image(systemName: "map")
                            Text("轨迹")
                        }
                    }
                    .tag(AppTab.tracks)

                EquipmentView()
                    .tabItem {
                        VStack(spacing: 2) {
                            Image(systemName: "backpack")
                            Text("装备")
                        }
                    }
                    .tag(AppTab.equipment)

                ProfileView()
                    .tabItem {
                        VStack(spacing: 2) {
                            Image(systemName: "person")
                            Text("我的")
                        }
                    }
                    .tag(AppTab.profile)
                }

            if showToast, let toastMessage {
                ImportToastView(message: toastMessage)
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .accentColor(AppDesign.accent)
        .onAppear {
            if store.tracks.isEmpty {
                store.importStatus = "等待导入GPX文件"
            }
        }
        .onReceive(store.$lastImportEvent) { event in
            guard let event else { return }
            selectedTab = .tracks
            toastMessage = "已导入 \(event.trackName)"
            withAnimation(.easeInOut(duration: 0.2)) {
                showToast = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                guard toastMessage == "已导入 \(event.trackName)" else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showToast = false
                }
            }
        }
    }
}

private struct ImportToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.appBody.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppDesign.accentDeep)
        .clipShape(Capsule())
        .shadow(color: AppDesign.shadow, radius: 16, x: 0, y: 8)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: TrackStore
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AppDesign.background, AppDesign.backgroundAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            AppStatusPill(text: "徒步轨迹助手", tint: AppDesign.accentDeep)

                            Text("更简单地规划、记录和分享每一次徒步。")
                                .font(.appHero)
                                .foregroundColor(AppDesign.ink)

                            Text("围绕 GPX 查看、智能路线规划、装备成本和分享生成，把徒步最常用的功能浓缩在一个清爽入口里。")
                                .font(.appBody)
                                .foregroundColor(AppDesign.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(24)
                        .appCardStyle()

                        VStack(spacing: 14) {
                            homeActionCard(
                                title: "GPX 导入",
                                subtitle: "一键导入两步路或本地 GPX，快速查看轨迹与海拔剖面。",
                                icon: "square.and.arrow.down.on.square",
                                tint: AppDesign.accent,
                                action: { selectedTab = .tracks }
                            )

                            homeActionCard(
                                title: "路线规划",
                                subtitle: "基于已导入轨迹继续查看、切段和规划多日行程。",
                                icon: "point.topleft.down.curvedto.point.bottomright.up",
                                tint: AppDesign.success,
                                action: { selectedTab = .tracks }
                            )

                            homeActionCard(
                                title: "装备管理",
                                subtitle: "录入装备价格、寿命和使用频次，准备核算每公里分摊成本。",
                                icon: "backpack",
                                tint: AppDesign.warning,
                                action: { selectedTab = .equipment }
                            )
                        }

                        recentTrackCard
                    }
                    .padding(.horizontal, AppDesign.horizontalPadding)
                    .padding(.vertical, 18)
                }
            }
            .navigationBarTitle(Text("徒步轨迹助手"), displayMode: .large)
        }
    }

    private func homeActionCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.appSection)
                        .foregroundColor(AppDesign.ink)
                    Text(subtitle)
                        .font(.appBody)
                        .foregroundColor(AppDesign.secondaryInk)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(20)
            .appCardStyle()
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var recentTrackCard: some View {
        if let track = store.tracks.first {
            Button(action: { selectedTab = .tracks }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近徒步")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.accent)

                    Text(track.name)
                        .font(.appSection)
                        .foregroundColor(AppDesign.ink)

                    HStack(spacing: 12) {
                        summaryChip(label: Formatter.distance(track.summary.distanceMeters))
                        summaryChip(label: Formatter.meters(track.summary.totalAscent))
                    }
                }
                .padding(22)
                .appCardStyle()
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func summaryChip(label: String) -> some View {
        Text(label)
            .font(.appCaption)
            .foregroundColor(AppDesign.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppDesign.elevatedSurface)
            .clipShape(Capsule())
    }
}

struct EquipmentView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var showAddSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AppDesign.background, AppDesign.backgroundAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("装备管理")
                                .font(.appTitle)
                                .foregroundColor(AppDesign.ink)

                            Text("录入装备价格、预计寿命和分类，先把徒步装备清单与每公里分摊成本建立起来。")
                                .font(.appBody)
                                .foregroundColor(AppDesign.secondaryInk)
                        }
                        .padding(24)
                        .appCardStyle()

                        Button(action: { showAddSheet = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("新增装备")
                                        .font(.appSection)
                                        .foregroundColor(.white)
                                    Text("录入名称、采购价格和预计使用里程。")
                                        .font(.appBody)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }
                            .padding(22)
                            .background(AppDesign.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())

                        if store.equipments.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("还没有装备")
                                    .font(.appSection)
                                    .foregroundColor(AppDesign.ink)
                                Text("先从最常用的鞋靴、背包或衣物开始录入，后面我们再把它们和徒步轨迹关联起来。")
                                    .font(.appBody)
                                    .foregroundColor(AppDesign.secondaryInk)
                            }
                            .padding(20)
                            .appCardStyle()
                        } else {
                            ForEach(EquipmentCategory.allCases.filter { hasItems(in: $0) }, id: \.id) { category in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(category.title)
                                        .font(.appCaption)
                                        .foregroundColor(AppDesign.accent)

                                    ForEach(items(in: category)) { equipment in
                                        equipmentRow(equipment)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppDesign.horizontalPadding)
                    .padding(.vertical, 18)
                }
            }
            .navigationBarTitle(Text("装备"), displayMode: .large)
            .sheet(isPresented: $showAddSheet) {
                AddEquipmentView()
                    .environmentObject(store)
            }
        }
    }

    private func equipmentRow(_ equipment: Equipment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(equipment.name)
                        .font(.appSection)
                        .foregroundColor(AppDesign.ink)
                    Text("采购价 ¥\(Int(equipment.purchasePrice)) · 预计 \(Int(equipment.expectedLifetimeKilometers)) km")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.secondaryInk)
                    Text("已关联 \(store.usageCount(for: equipment.id)) 次 · 累计 \(String(format: "%.1f", store.usageDistanceKilometers(for: equipment.id))) km")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.secondaryInk)
                }
                Spacer()
                AppStatusPill(
                    text: String(format: "¥%.2f / km", equipment.costPerKilometer),
                    tint: AppDesign.accentDeep
                )
            }

            if !equipment.notes.isEmpty {
                Text(equipment.notes)
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            }
        }
        .padding(20)
        .appCardStyle()
    }

    private func items(in category: EquipmentCategory) -> [Equipment] {
        store.equipments.filter { $0.category == category }
    }

    private func hasItems(in category: EquipmentCategory) -> Bool {
        items(in: category).isEmpty == false
    }
}

struct AddEquipmentView: View {
    @EnvironmentObject private var store: TrackStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var name = ""
    @State private var category: EquipmentCategory = .footwear
    @State private var purchasePrice = ""
    @State private var expectedLifetimeKilometers = ""
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基础信息")) {
                    TextField("装备名称", text: $name)
                    Picker("分类", selection: $category) {
                        ForEach(EquipmentCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section(header: Text("成本参数")) {
                    TextField("采购价格", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                    TextField("预计使用里程（km）", text: $expectedLifetimeKilometers)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("备注")) {
                    TextField("可选备注", text: $notes)
                }
            }
            .navigationBarTitle(Text("新增装备"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    save()
                }
                .disabled(!canSave)
            )
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(purchasePrice) != nil
            && Double(expectedLifetimeKilometers) != nil
    }

    private func save() {
        guard
            let price = Double(purchasePrice),
            let lifetime = Double(expectedLifetimeKilometers)
        else {
            return
        }

        let equipment = Equipment(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            purchasePrice: price,
            expectedLifetimeKilometers: lifetime,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        store.addEquipment(equipment)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AppDesign.background, AppDesign.backgroundAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("我的")
                                .font(.appTitle)
                                .foregroundColor(AppDesign.ink)
                            Text("这里将承接徒步统计、分享记录、会员与数据备份。")
                                .font(.appBody)
                                .foregroundColor(AppDesign.secondaryInk)
                        }
                        .padding(24)
                        .appCardStyle()

                        profileStatCard(title: "累计徒步里程", value: totalDistance)
                        profileStatCard(title: "平均每公里装备费用", value: averageEquipmentCost)
                        profileStatCard(title: "已录入装备数量", value: "\(store.equipments.count)")
                    }
                    .padding(.horizontal, AppDesign.horizontalPadding)
                    .padding(.vertical, 18)
                }
            }
            .navigationBarTitle(Text("我的"), displayMode: .large)
        }
    }

    private var averageEquipmentCost: String {
        guard !store.equipments.isEmpty else { return "--" }
        let average = store.equipments.map(\.costPerKilometer).reduce(0, +) / Double(store.equipments.count)
        return String(format: "¥%.2f / km", average)
    }

    private var totalDistance: String {
        let total = store.tracks.map { $0.summary.distanceMeters }.reduce(0, +)
        return total > 0 ? Formatter.distance(total) : "--"
    }

    private func profileStatCard(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
            Spacer()
            Text(value)
                .font(.appSection)
                .foregroundColor(AppDesign.ink)
        }
        .padding(20)
        .appCardStyle()
    }
}
