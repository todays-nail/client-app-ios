//
//  HomeView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Home (임시)")
                    .font(.title2.bold())
                Text("여기부터 피드/상세/AI/예약 화면으로 확장")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("오늘 네일")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("로그아웃") {
                        Task { await appViewModel.signOut() }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
}
