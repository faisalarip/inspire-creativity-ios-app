-- ─────────────────────────────────────────────────────────────
-- Enigma iOS app — usage_mockups table + 30 seed rows
-- Paste into Supabase Dashboard → SQL Editor → Run.
-- Idempotent: safe to re-run.
-- ─────────────────────────────────────────────────────────────

create table if not exists usage_mockups (
  id          text primary key,
  title       text not null,
  app_name    text not null,
  aurora_id   text not null,      -- references animations.id (no FK so seed loose)
  context     text not null,
  why         text not null,
  swift_code  text not null,
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table usage_mockups enable row level security;

drop policy if exists "usage_mockups are publicly readable" on usage_mockups;
create policy "usage_mockups are publicly readable"
  on usage_mockups for select
  using (true);

drop trigger if exists usage_mockups_set_updated_at on usage_mockups;
create trigger usage_mockups_set_updated_at
  before update on usage_mockups
  for each row execute function set_updated_at();

create index if not exists usage_mockups_position_idx on usage_mockups(position);
create index if not exists usage_mockups_aurora_idx   on usage_mockups(aurora_id);

-- ─────────────────────────────────────────────────────────────
-- 30 seed rows, in display order. Re-run replaces existing rows
-- by id via the ON CONFLICT clause at the bottom.
-- ─────────────────────────────────────────────────────────────

insert into usage_mockups
  (id, title, app_name, aurora_id, context, why, swift_code, position)
values
  ('mock-ai-chat', 'AI Assistant', 'Intelligence', 'aurora-mesh', 'AI · LLM chat', 'Aurora moves while AI reasons — signals "thinking" without a stale spinner.', 'import SwiftUI

struct IntelligenceChat: View {
    @State private var isThinking = true
    @State private var messages: [Message] = []

    var body: some View {
        ZStack(alignment: .top) {
            // Aurora fades down — only visible in the top half
            AuroraMesh()
                .frame(height: 380)
                .mask(LinearGradient(
                    colors: [.black, .black, .clear],
                    startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                IntelligenceHeader()
                if isThinking { ThinkingBubble() }
                ChatList(messages: messages)
                Composer()
            }
            .padding(.top, 60)
        }
        .background(.black)
    }
}', 0),
  ('mock-onboarding', 'Onboarding Splash', 'NorthLight', 'aurora-borealis', 'Aurora-tracker onboarding', 'Northern lights as literal product — instant emotional hook in 1 second.', 'import SwiftUI

struct WelcomeScreen: View {
    var body: some View {
        ZStack {
            AuroraBorealis()
                .overlay(
                    RadialGradient(
                        colors: [.clear, .clear, .black.opacity(0.6)],
                        center: .center, startRadius: 100, endRadius: 400
                    )
                )
                .ignoresSafeArea()

            VStack {
                BrandMark().padding(.top, 30)
                Spacer()
                Text("See the sky\\nwhere you sleep.")
                    .font(.system(size: 36, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Spacer()
                Button("Start tracking") { /* … */ }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
    }
}', 1),
  ('mock-paywall', 'Pro Paywall', 'Folio', 'liquid-chrome', 'Premium upgrade', 'Iridescent metal reads as "premium" — increases conversion.', 'import SwiftUI

struct FolioPaywall: View {
    var body: some View {
        ZStack(alignment: .top) {
            LiquidChrome()
                .frame(height: 380)
                .mask(LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 18) {
                ChromeLogo().padding(.top, 80)
                Text("Folio Pro")
                    .font(.system(size: 28, weight: .heavy))
                Text("Unlimited portfolios. Pro analytics. White-glove sync.")
                    .foregroundStyle(.secondary)
                FeatureList()
                Spacer()
                Button(action: subscribe) {
                    Text("Start 7-day free trial · $14.99/mo")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.horizontal, 24)
            }
        }
        .background(.black)
    }
}', 2),
  ('mock-music', 'Now Playing', 'Late Bloom', 'aurora-pulse', 'Music player', 'Background pulses with bass — passive engagement during listening.', 'import SwiftUI

struct NowPlayingScreen: View {
    @State private var peak = AudioPeak()  // observed peak power
    let track: Track

    var body: some View {
        ZStack {
            AuroraPulse()
                .environment(peak)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                PlayerHeader(track: track)
                AlbumArt(track: track)
                    .frame(width: 220, height: 220)
                    .shadow(radius: 30, y: 20)
                TrackInfo(track: track)
                Scrubber(track: track)
                PlaybackControls()
            }
        }
        .onAppear { peak.start() }
    }
}', 3),
  ('mock-success', 'Success Moment', 'Onboarding', 'aurora-bloom', 'Plan upgrade success', 'Bloom radiates from center — celebrates completion as a payoff.', 'import SwiftUI

struct PlanUpgradedScreen: View {
    let plan: Plan

    var body: some View {
        ZStack {
            AuroraBloom()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                Capsule().fill(.thinMaterial)
                    .frame(width: 120, height: 26)
                    .overlay(Text("PLAN UPGRADED")
                        .font(.caption2.bold().monospaced()))
                Text("Welcome\\naboard.")
                    .font(.system(size: 42, weight: .black))
                    .multilineTextAlignment(.center)
                Text("Your premium features are unlocked.")
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button("Set up project") { route(.projectSetup) }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
            }
        }
    }
}', 4),
  ('mock-reading', 'Book Detail', 'Paperbound', 'aurora-marble', 'E-reader', 'Marble as paper texture — establishes editorial, tactile mood.', 'import SwiftUI

struct BookDetailScreen: View {
    let book: Book

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    AuroraMarble()
                        .frame(height: 380)
                    BookCover(book: book)
                        .frame(width: 130, height: 195)
                        .rotation3DEffect(.degrees(4),
                                          axis: (x: 0, y: 1, z: 0))
                        .shadow(radius: 20, y: 10)
                }
                BookMeta(book: book)
                    .padding(22)
                    .background(Color(hex: "f5ede0"))
                Spacer(minLength: 200)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}', 5),
  ('mock-fitness', 'HIIT Timer', 'Forge', 'lava-flow', 'Workout timer', 'Lava drives intensity — visual heat pushes the workout.', 'import SwiftUI

struct HIITTimerScreen: View {
    @State private var seconds = 42
    @State private var phase: WorkoutPhase = .work
    let round: Int

    var body: some View {
        ZStack {
            LavaFlow().ignoresSafeArea()
                .overlay(.black.opacity(0.3))

            VStack(spacing: 0) {
                HIITHeader(round: round)
                Spacer()
                Text(timecode(seconds))
                    .font(.system(size: 108, weight: .black,
                                  design: .monospaced))
                    .shadow(color: .orange.opacity(0.6), radius: 30, y: 8)
                Text("Mountain Climbers")
                    .font(.title.bold())
                Spacer()
                PlayPauseControls()
                    .padding(.bottom, 40)
            }
        }
    }
}', 6),
  ('mock-crypto-wallet', 'Crypto Wallet', 'Wavelet', 'au-sunset', 'Personal finance', 'Warm aurora softens hard numbers — feels like wealth, not anxiety.', 'import SwiftUI

struct WalletScreen: View {
    @State private var holdings: [Holding] = []

    var body: some View {
        ZStack {
            AuroraSunset().ignoresSafeArea()

            VStack(spacing: 18) {
                WalletHeader()

                VStack(spacing: 4) {
                    Text("TOTAL BALANCE")
                        .font(.caption2).tracking(2).opacity(0.6)
                    Text("$24,820")
                        .font(.system(size: 44, weight: .heavy,
                                      design: .monospaced))
                        .contentTransition(.numericText())
                    Text("↑ +5.30% today").foregroundStyle(.green)
                }

                ActionRow()
                HoldingsList(holdings: holdings)
                    .background(.ultraThinMaterial,
                                in: .rect(cornerRadius: 18))
            }
            .padding()
        }
    }
}', 7),
  ('mock-meditation', 'Meditation Session', 'Stillness', 'au-calmdrift', 'Mindfulness', 'Calm drift mirrors breath — viewers naturally synchronize.', 'import SwiftUI

struct BreathingSession: View {
    @State private var inhale = true
    let totalSeconds = 600

    var body: some View {
        ZStack {
            CalmDrift().ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Day 12 · Awareness")
                    .font(.caption).tracking(2.5).opacity(0.65)

                // The circle that breathes with the user
                BreathCircle(isInhaling: inhale)
                    .frame(width: 160, height: 160)

                CountdownLabel(seconds: totalSeconds)
                PauseButton().padding(.top)
            }
        }
        .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 4)) {
                inhale.toggle()
            }
        }
    }
}', 8),
  ('mock-sleep', 'Sleep Tracking', 'Dreamweave', 'au-midnight', 'Sleep score', 'Aurora midnight feels nocturnal — the bg sells the context before any UI.', 'import SwiftUI

struct SleepSummaryScreen: View {
    let session: SleepSession

    var body: some View {
        ZStack {
            AuroraMidnight().ignoresSafeArea()
                .overlay(.black.opacity(0.2))

            VStack(alignment: .leading, spacing: 18) {
                SleepHeader(date: session.date, score: session.score)

                Text(session.formattedDuration)
                    .font(.system(size: 76, weight: .heavy,
                                  design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)

                SleepStagesBar(stages: session.stages)
                StageLegend(stages: session.stages)

                Spacer()
                InsightCard(insight: session.insight)
            }
            .padding()
        }
    }
}', 9),
  ('mock-weather', 'Weather Forecast', 'Skyline', 'au-storm', 'Weather app', 'Storm Front bg signals conditions before reading any number.', 'import SwiftUI

struct WeatherScreen: View {
    let forecast: Forecast

    var body: some View {
        ZStack {
            // Background switches by condition
            switch forecast.condition {
            case .storm:    StormFront()
            case .sunny:    AuroraSunset()
            case .cloudy:   CloudVeil()
            }
            // ...

            VStack(spacing: 14) {
                LocationName(forecast.location)
                Text("\\(forecast.temp)°")
                    .font(.system(size: 84, weight: .ultraLight))
                Text(forecast.conditionLabel)
                HighLow(forecast: forecast)
                HourlyForecast(hours: forecast.hourly)
                if let alert = forecast.alert { AlertBanner(alert) }
            }
        }
        .ignoresSafeArea()
    }
}', 10),
  ('mock-bank-success', 'Transfer Sent', 'BluePay', 'au-solar', 'Banking confirmation', 'Solar burst behind the checkmark = pure satisfaction.', 'import SwiftUI

struct TransferSuccessScreen: View {
    let transfer: Transfer

    var body: some View {
        ZStack {
            SolarFlare().ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                CheckmarkBadge()
                    .scaleEffect(showCheck ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55),
                               value: showCheck)
                Text("Transfer sent")
                    .font(.system(size: 32, weight: .heavy))
                Text("To \\(transfer.recipient) · \\(transfer.maskedAccount)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(transfer.amount.formatted(.currency(code: "IDR")))
                    .font(.system(size: 56, weight: .heavy,
                                  design: .monospaced))
                Spacer()
                HStack {
                    Button("Share receipt") {}.buttonStyle(.bordered)
                    Button("Done") {}.buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
        }
        .onAppear { showCheck = true }
    }
}', 11),
  ('mock-photo-gallery', 'Photo Memories', 'Bokeh', 'au-bokeh', 'Photo gallery', 'Soft Bokeh dots echo lens blur — feels like film, not phone.', 'import SwiftUI

struct MemoriesScreen: View {
    @State private var photos: [Photo] = []

    var body: some View {
        ZStack(alignment: .top) {
            SoftBokeh().ignoresSafeArea()
                .opacity(0.85)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GalleryHeader()
                    Text("Featured collection")
                        .font(.caption).opacity(0.6)
                    Text("Spring in Tokyo")
                        .font(.title2.bold())

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 6) {
                        ForEach(photos) { photo in
                            PhotoTile(photo: photo)
                        }
                    }
                }
                .padding()
            }
        }
    }
}', 12),
  ('mock-launch-splash', 'Launch Splash', 'Orbit', 'au-galaxy', 'App launch screen', 'Galaxy spin gives 1.5s of magic instead of a dead loading dot.', 'import SwiftUI

@main
struct OrbitApp: App {
    @State private var ready = false

    var body: some Scene {
        WindowGroup {
            if ready {
                MainTabView()
            } else {
                ZStack {
                    GalaxySpiral().ignoresSafeArea()

                    VStack {
                        AppLogo()
                            .scaleEffect(ready ? 1 : 0.92)
                            .symbolEffect(.pulse)
                        Text("Orbit").font(.system(size: 32, weight: .heavy))
                        Text("Find your gravity.").opacity(0.65)
                    }
                }
                .task {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation(.easeOut(duration: 0.4)) { ready = true }
                }
            }
        }
    }
}', 13),
  ('mock-audio-call', 'Live Audio Room', 'Tuesday Studio', 'au-pulsar', 'Clubhouse-style audio', 'Pulsar beats with the active speaker — engagement signal you can feel.', 'import SwiftUI

struct AudioRoomScreen: View {
    @State private var speakers: [Speaker] = []
    @State private var activeSpeaker: Speaker?

    var body: some View {
        ZStack {
            AuroraPulse()
                .environment(\\.audioLevel,
                             activeSpeaker?.level ?? 0)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                RoomHeader(title: "Late-night design crits")
                SpeakerGrid(speakers: speakers,
                            active: activeSpeaker)
                Spacer()
                ReactionRow()
            }
        }
    }
}', 14),
  ('mock-voice-assistant', 'Voice Assistant', 'Aria', 'au-pearl', 'Voice listening state', 'Pearl iridescence reads as "intelligent listening" not "stuck".', 'import SwiftUI

struct VoiceListenScreen: View {
    @State private var transcript = ""
    @State private var amplitude: Double = 0
    let recognizer = SpeechRecognizer()

    var body: some View {
        ZStack {
            PearlSheen().ignoresSafeArea()

            VStack(spacing: 28) {
                Text("LISTENING…")
                    .font(.caption.bold()).tracking(2).opacity(0.65)

                LiveTranscript(text: transcript)
                    .padding(.horizontal, 28)

                Waveform(amplitude: amplitude)
                    .frame(height: 50)

                HelperText()
            }
        }
        .task {
            for await update in recognizer.stream() {
                transcript = update.text
                amplitude = update.amplitude
            }
        }
    }
}', 15),
  ('mock-nft', 'NFT Detail', 'Strata', 'au-holofoil', 'NFT / collectibles marketplace', 'Holographic foil shimmer is the universal "rare" signal.', 'import SwiftUI

struct NFTDetailScreen: View {
    let item: NFTItem

    var body: some View {
        ZStack {
            HolographicFoil().ignoresSafeArea()

            VStack(spacing: 0) {
                NFTNavBar()
                Spacer()
                NFTCard(item: item)
                    .rotation3DEffect(.degrees(-8),
                                      axis: (x: 0.5, y: 1, z: 0))
                    .shadow(radius: 30, y: 20)
                Spacer()
                BidPanel(item: item)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
    }
}', 16),
  ('mock-astrology', 'Daily Horoscope', 'Astralis', 'au-nebula', 'Astrology · horoscope', 'Nebula deepens the mystical, makes the words land harder.', 'import SwiftUI

struct DailyHoroscopeScreen: View {
    let reading: Horoscope
    let sign: ZodiacSign

    var body: some View {
        ZStack {
            NebulaDrift().ignoresSafeArea()

            VStack(spacing: 18) {
                Text(reading.dateLabel)
                    .font(.caption).tracking(2)
                Text("Your stars")
                    .font(.custom("Georgia-Italic", size: 30))

                Text(sign.glyph).font(.system(size: 60))
                Text(sign.name.uppercased())
                    .font(.caption).tracking(2)

                Text(reading.body)
                    .font(.custom("Georgia-Italic", size: 17))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                ReadingStatsRow(stats: reading.stats)
                Spacer()
                Button("Read full reading") {}
            }
        }
    }
}', 17),
  ('mock-dating', 'Profile Card', 'Soirée', 'au-sparkleveil', 'Dating app', 'Sparkle veil keeps it romantic without being saccharine.', 'import SwiftUI

struct ProfileCardScreen: View {
    let profile: DatingProfile

    var body: some View {
        ZStack {
            SparkleVeil().ignoresSafeArea()

            VStack(spacing: 14) {
                PhotoCarousel(photos: profile.photos)
                    .frame(height: 380)
                    .clipShape(.rect(cornerRadius: 22))
                    .padding()

                BioCard(profile: profile)
                    .padding(.horizontal)

                Spacer()

                SwipeActions()
                    .padding(.bottom, 30)
            }
        }
    }
}', 18),
  ('mock-yoga', 'Yoga Pose Timer', 'Asana', 'au-ethereal', 'Yoga / mindfulness', 'Ethereal Mist is wash-of-calm — perfect under hold timers.', 'import SwiftUI

struct YogaPoseScreen: View {
    @State private var secondsLeft = 38
    let pose: Pose

    var body: some View {
        ZStack {
            EtherealMist().ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Morning Flow · Pose 4 of 12")
                    .font(.caption).tracking(2).opacity(0.6)
                PoseIllustration(pose: pose)
                    .font(.system(size: 80))
                Text(pose.name)
                    .font(.custom("Georgia", size: 26))
                Text(pose.cue).italic().opacity(0.65)
                CircularTimer(seconds: secondsLeft, total: 60)
                    .frame(width: 160, height: 160)
                PoseControls()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
        }
    }
}', 19),
  ('mock-coin-detail', 'Coin Detail', 'Wavelet', 'au-blackhole', 'Crypto · trading', 'Black Hole gravitas frames the chart — risk made tangible.', 'import SwiftUI
import Charts

struct CoinDetailScreen: View {
    let coin: Coin
    @State private var range: TimeRange = .week

    var body: some View {
        ZStack {
            BlackHole().ignoresSafeArea()

            VStack(spacing: 14) {
                CoinHeader(coin: coin)
                Text(coin.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 38, weight: .heavy,
                                  design: .monospaced))
                ChangeBadge(delta: coin.change24h)

                Chart(coin.candles) { candle in
                    AreaMark(x: .value("t", candle.time),
                             y: .value("p", candle.close))
                        .foregroundStyle(LinearGradient(
                            colors: [.green.opacity(0.4), .clear],
                            startPoint: .top, endPoint: .bottom))
                }
                .frame(height: 160)

                TimeRangePicker(selection: $range)
                Spacer()
                BuySellRow(coin: coin)
            }
            .padding()
        }
    }
}', 20),
  ('mock-sub-unlocked', 'Premium Unlocked', 'Wavelength', 'au-goldfoil', 'Subscription activated', 'Gold foil = literal "golden moment" — celebrate the conversion.', 'import SwiftUI

struct PremiumUnlockedScreen: View {
    @State private var shown = false

    var body: some View {
        ZStack {
            GoldFoil().ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Capsule().fill(.thinMaterial)
                    .frame(width: 200, height: 28)
                    .overlay(Text("⭐ PREMIUM ACTIVATED").font(.caption2.bold()))
                Text("You''re\\ngolden.")
                    .font(.system(size: 38, weight: .black))
                    .multilineTextAlignment(.center)
                Text("Welcome to Wavelength Pro.")
                    .opacity(0.85)
                UnlockedFeaturesList()
                Spacer()
                Button("Start using Pro") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .padding(.horizontal)
            }
        }
        .onAppear { showConfetti() }
    }
}', 21),
  ('mock-workout-summary', 'Workout Summary', 'Forge', 'au-firewall', 'Run · cycle summary', 'Firewall = visceral effort, satisfying after a hard session.', 'import SwiftUI

struct WorkoutSummaryScreen: View {
    let session: WorkoutSession

    var body: some View {
        ZStack {
            Firewall().ignoresSafeArea()
                .overlay(.black.opacity(0.25))

            VStack(alignment: .leading, spacing: 16) {
                SummaryHeader(date: session.date)
                Text("Burned bright today.")
                    .font(.system(size: 30, weight: .heavy))

                StatGrid(stats: session.stats)
                HeartRateCard(samples: session.heartRate)

                if let pr = session.personalRecord {
                    PRBadge(record: pr)
                }
                Spacer()
            }
            .padding()
        }
    }
}', 22),
  ('mock-ticket', 'Event Ticket', 'Curtain', 'au-stardust', 'Wallet · ticketing', 'Stardust makes a flat PDF ticket feel like the show already started.', 'import SwiftUI

struct ConcertTicketScreen: View {
    let ticket: Ticket

    var body: some View {
        ZStack {
            StardustField().ignoresSafeArea()

            VStack {
                Text("YOUR TICKET")
                    .font(.caption).tracking(2).opacity(0.7)
                    .padding(.top, 20)

                TicketCard(ticket: ticket)
                    .padding()
                    .ticketStyle()  // dashed perforation + notches

                Spacer()

                Button("Add to Wallet") { addToAppleWallet(ticket) }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
    }
}', 23),
  ('mock-year-review', 'Year in Review', 'Forge', 'au-supernova', 'Annual recap · Wrapped', 'Supernova = climactic — pairs with the year-defining stat.', 'import SwiftUI

struct YearInReviewSlide: View {
    let stat: ReviewStat

    var body: some View {
        ZStack {
            SupernovaBurst().ignoresSafeArea()

            VStack(spacing: 14) {
                Capsule().fill(.thinMaterial)
                    .frame(width: 130, height: 24)
                    .overlay(Text("2025 · WRAPPED").font(.caption2.bold()))
                Text("You ran")
                    .font(.system(size: 30, weight: .black))
                Text("\\(stat.value)")
                    .font(.system(size: 80, weight: .black))
                    .foregroundStyle(.yellow)
                    .contentTransition(.numericText())
                Text("kilometers.")
                    .font(.system(size: 30, weight: .black))
                Text(stat.context).opacity(0.75)
                Spacer()
                StatTiles(stats: stat.supporting)
                Button("Share your year") { share() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white).foregroundStyle(.black)
            }
            .padding()
        }
    }
}', 24),
  ('mock-empty-inbox', 'Inbox Zero', 'Pebble Mail', 'au-calmdrift', 'Empty state', 'Calm drift turns "nothing to do" into "moment to breathe".', 'import SwiftUI

struct InboxView: View {
    @Query var messages: [Message]

    var body: some View {
        ZStack {
            // Aurora ONLY when empty — when there''s mail, plain background
            if messages.isEmpty {
                CalmDrift().ignoresSafeArea()
                    .transition(.opacity)
            }

            if messages.isEmpty {
                ContentUnavailableView {
                    Text("🍃").font(.system(size: 80))
                } description: {
                    Text("You''re all caught up.")
                        .font(.custom("Georgia", size: 24))
                    Text("Maybe take a moment, look up, breathe.")
                }
            } else {
                MessageList(messages: messages)
            }
        }
        .animation(.easeInOut, value: messages.isEmpty)
    }
}', 25),
  ('mock-recipe', 'Recipe Card', 'Hearth', 'au-honeydrip', 'Cooking · recipes', 'Honey Drip evokes warmth + taste — appetite-stimulating.', 'import SwiftUI

struct RecipeDetailScreen: View {
    let recipe: Recipe
    @State private var checkedIngredients = Set<Ingredient.ID>()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    HoneyDrip()
                        .frame(height: 320)
                    NavButtons().padding()
                }

                VStack(alignment: .leading, spacing: 14) {
                    RecipeMeta(recipe: recipe)
                    Text(recipe.title)
                        .font(.custom("Georgia", size: 24).bold())
                    TagRow(tags: recipe.tags)
                    IngredientChecklist(
                        ingredients: recipe.ingredients,
                        checked: $checkedIngredients
                    )
                    StartCookingButton(recipe: recipe)
                }
                .padding()
                .background(Color(hex: "FEF3C7"))
                .clipShape(.rect(cornerRadii: .init(topLeading: 24,
                                                    topTrailing: 24)))
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}', 26),
  ('mock-travel', 'Travel Destination', 'Compass', 'au-tropics', 'Travel · discovery', 'Tropical Haze previews the destination vibe before any photo.', 'import SwiftUI

struct DestinationScreen: View {
    let destination: Destination

    var body: some View {
        ZStack(alignment: .top) {
            // Theme-aware background — picks aurora by destination climate
            destination.climate.auroraBackground
                .frame(height: 500)
                .mask(LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TravelNav()
                Spacer()
                VStack(spacing: 4) {
                    Text("DISCOVER · \\(destination.country.uppercased())")
                        .font(.caption).tracking(2)
                    Text(destination.name)
                        .font(.custom("Georgia-Italic", size: 42).bold())
                    HStack {
                        Text("☀️ \\(destination.tempLabel)")
                        Text("🏝 \\(destination.placesCount) places")
                        Text(destination.priceLabel)
                    }
                    .font(.caption).opacity(0.85)
                }
                TopPicksSheet(picks: destination.topPicks)
            }
        }
    }
}', 27),
  ('mock-loyalty', 'Tier Upgrade', 'Lumière', 'au-goldfoil', 'Hotel · loyalty programs', 'Bronze → Gold transition feels like an actual coronation.', 'import SwiftUI

struct TierUpgradeScreen: View {
    let oldTier: Tier  // .bronze
    let newTier: Tier  // .gold

    @State private var phase: AnimationPhase = .entering

    var body: some View {
        ZStack {
            GoldFoil().ignoresSafeArea()
                .opacity(phase == .arrived ? 1 : 0.5)

            VStack(spacing: 18) {
                Text("TIER UPGRADE")
                    .font(.caption).tracking(2)

                TierTransition(from: oldTier, to: newTier, phase: phase)
                    .frame(height: 150)

                Text("Welcome to Gold")
                    .font(.system(size: 28, weight: .heavy))
                Text("You''ve spent enough nights with us…")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                BenefitsList(benefits: newTier.benefits)

                Spacer()
                Button("See all benefits") {}
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
            }
            .padding()
        }
        .task {
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                phase = .arrived
            }
        }
    }
}', 28),
  ('mock-achievement', 'Achievement Unlocked', 'Streak', 'au-coreburst', 'Gamification · milestone', 'Core Burst behind a trophy = visceral reward firing in the brain.', 'import SwiftUI

struct AchievementUnlockedScreen: View {
    let achievement: Achievement

    var body: some View {
        ZStack {
            CoreBurst().ignoresSafeArea()

            VStack(spacing: 18) {
                Capsule().fill(.thinMaterial)
                    .frame(width: 200, height: 22)
                    .overlay(Text("ACHIEVEMENT UNLOCKED")
                        .font(.caption2.bold()))

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3),
                                style: .init(lineWidth: 2, dash: [4]))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(spinning ? 360 : 0))

                    TrophyBadge()
                        .frame(width: 130, height: 130)
                        .shadow(color: .orange.opacity(0.6), radius: 50)
                }

                Text(achievement.title)
                    .font(.custom("Georgia", size: 26).bold())
                Text(achievement.subtitle)
                    .multilineTextAlignment(.center)
                    .opacity(0.75)

                RewardCard(reward: achievement.reward)
                Spacer()
                ActionButtons()
            }
        }
        .onAppear { spinning = true }
    }
}', 29)
on conflict (id) do update set
  title      = excluded.title,
  app_name   = excluded.app_name,
  aurora_id  = excluded.aurora_id,
  context    = excluded.context,
  why        = excluded.why,
  swift_code = excluded.swift_code,
  position   = excluded.position;
