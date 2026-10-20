import { useEffect, useRef, useState } from 'react'

const BOARD_KEY = 'heycutu-leaderboard'
const QUESTIONS = [
  { q: 'Mera comfort food kya hai?', options: ['Pizza 🍕', 'Biryani 🍛', 'Pasta 🍝', 'Dosa 🥞'] },
  { q: 'Dream date destination?', options: ['Mountains 🏔️', 'Beach 🌊', 'Paris 🗼', 'Cozy staycation 🛋️'] },
  { q: 'Perfect weekend plan?', options: ['Movie night 🎬', 'Road trip 🚗', 'Cafe hopping ☕', 'Lazy day 💤'] },
  { q: 'Meri love language?', options: ['Sweet words 💌', 'Quality time 🕯️', 'Little gifts 🎁', 'Hugs 🤗'] },
  { q: 'Late-night craving?', options: ['Maggi 🍜', 'Ice cream 🍦', 'Chaat 🌶️', 'Nothing, just sleep 😴'] },
  { q: 'Choose our couple vibe', options: ['Cute & cheesy 💗', 'Chaotic duo 🤪', 'Power couple ⚡', 'Soft & cozy ☁️'] },
  { q: 'Ideal surprise?', options: ['Handwritten note 💌', 'Spontaneous trip 🎒', 'Favourite food 🍰', 'Long hug 🫶'] },
  { q: 'Who says “I love you” first?', options: ['Me 🙋', 'You 👉', 'Both at once 💞', 'Every five minutes 😂'] },
]

const shuffle = (items) => {
  const copy = [...items]
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}

function loadBoard() {
  try {
    const saved = JSON.parse(localStorage.getItem(BOARD_KEY) || '[]')
    return Array.isArray(saved) ? saved : []
  } catch {
    return []
  }
}

function saveBoard(board) {
  try {
    localStorage.setItem(BOARD_KEY, JSON.stringify(board))
  } catch {
    // Keep the game playable if browser storage is unavailable.
  }
}

export default function App() {
  const [screen, setScreen] = useState('home')
  const [names, setNames] = useState({ p1: '', p2: '' })
  const [error, setError] = useState('')
  const [rounds, setRounds] = useState([])
  const [idx, setIdx] = useState(0)
  const [picks, setPicks] = useState({ p1: null, p2: null })
  const [score, setScore] = useState(0)
  const [matches, setMatches] = useState(0)
  const [board, setBoard] = useState(loadBoard)
  const touchStart = useRef(null)

  const coupleName = `${names.p1.trim()} & ${names.p2.trim()}`
  const revealed = picks.p1 !== null && picks.p2 !== null
  const currentQuestion = rounds[idx]
  const isMatch = revealed && picks.p1 === picks.p2

  function startGame() {
    if (!names.p1.trim() || !names.p2.trim()) {
      setError('Dono partners ke naam enter karein 💗')
      return
    }
    setError('')
    setRounds(shuffle(QUESTIONS).slice(0, 5))
    setIdx(0)
    setPicks({ p1: null, p2: null })
    setScore(0)
    setMatches(0)
    setScreen('game')
  }

  function pick(player, optionIndex) {
    if (picks[player] !== null) return
    setPicks((current) => ({ ...current, [player]: optionIndex }))
  }

  function nextRound() {
    if (!revealed) return
    const nextScore = score + (isMatch ? 100 : 20)
    const nextMatches = matches + (isMatch ? 1 : 0)
    if (idx + 1 >= rounds.length) {
      const entry = {
        couple: coupleName,
        score: nextScore,
        matches: nextMatches,
        date: new Date().toLocaleDateString('en-IN'),
      }
      const updated = [...board, entry].sort((a, b) => b.score - a.score).slice(0, 10)
      setBoard(updated)
      saveBoard(updated)
      setScore(nextScore)
      setMatches(nextMatches)
      setScreen('result')
      return
    }
    setScore(nextScore)
    setMatches(nextMatches)
    setIdx((current) => current + 1)
    setPicks({ p1: null, p2: null })
  }

  useEffect(() => {
    function handleKeyDown(event) {
      if ((event.key === 'ArrowRight' || event.key === 'Enter') && screen === 'game' && revealed) {
        nextRound()
      }
      if (event.key === 'Escape' && screen === 'game') setScreen('home')
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  })

  function handleTouchEnd(event) {
    if (touchStart.current === null || !revealed) return
    const delta = event.changedTouches[0].clientX - touchStart.current
    if (delta < -65) nextRound()
    touchStart.current = null
  }

  function clearBoard() {
    if (window.confirm('Leaderboard clear kar dein?')) {
      setBoard([])
      saveBoard([])
    }
  }

  return (
    <div className="app-shell">
      <div className="ambient ambient-one" aria-hidden="true" />
      <div className="ambient ambient-two" aria-hidden="true" />

      <header className="topbar">
        <button className="wordmark" onClick={() => setScreen('home')} aria-label="HeyCutu home">
          <span className="wordmark-icon">♡</span>
          <span>heycutu<span className="wordmark-dot">.</span></span>
        </button>
        <nav className="topnav" aria-label="Main navigation">
          <button className={screen !== 'leaderboard' ? 'nav-link active' : 'nav-link'} onClick={() => setScreen('home')}>Play</button>
          <button className={screen === 'leaderboard' ? 'nav-link active' : 'nav-link'} onClick={() => setScreen('leaderboard')}>Leaderboard <span className="nav-trophy">↗</span></button>
        </nav>
      </header>

      <main className="main-content">
        {screen === 'home' && (
          <section className="welcome-view animate-in">
            <div className="eyebrow"><span className="eyebrow-spark">✦</span> MADE FOR TWO <span className="eyebrow-spark">✦</span></div>
            <h1>How well do you<br /><span>know your person?</span></h1>
            <p className="hero-copy">A little love, a little competition, and a whole lot of “that’s so us.”</p>

            <div className="game-preview" aria-hidden="true">
              <div className="preview-orbit orbit-one" />
              <div className="preview-orbit orbit-two" />
              <div className="preview-heart heart-left">♡</div>
              <div className="preview-heart heart-right">♥</div>
              <div className="preview-card card-back"><span>YOUR</span><strong>PERSON</strong><i>✦</i></div>
              <div className="preview-card card-front"><span>THE</span><strong>LOVE QUIZ</strong><i>♡</i></div>
              <div className="preview-spark spark-one">✦</div>
              <div className="preview-spark spark-two">✧</div>
            </div>

            <section className="setup-card">
              <div className="setup-heading">
                <div><span className="step-label">YOUR LITTLE DUO</span><h2>Who's playing today?</h2></div>
                <span className="duo-icon">♡</span>
              </div>
              <div className="name-fields">
                <label className="name-field">
                  <span>PARTNER ONE</span>
                  <input value={names.p1} maxLength={20} autoComplete="given-name" onChange={(e) => { setNames({ ...names, p1: e.target.value }); setError('') }} onKeyDown={(e) => e.key === 'Enter' && startGame()} placeholder="Your name" />
                </label>
                <div className="name-ampersand">&</div>
                <label className="name-field">
                  <span>PARTNER TWO</span>
                  <input value={names.p2} maxLength={20} autoComplete="off" onChange={(e) => { setNames({ ...names, p2: e.target.value }); setError('') }} onKeyDown={(e) => e.key === 'Enter' && startGame()} placeholder="Their name" />
                </label>
              </div>
              {error && <p className="error-message" role="alert">{error}</p>}
              <button className="primary-button" onClick={startGame}><span>Start your love story</span><span className="button-arrow">↗</span></button>
              <div className="setup-meta"><span>♡ 5 quick questions</span><span>✦ Just for fun</span><span>◷ 2–3 min</span></div>
            </section>
            <p className="tiny-note">No pressure. Just vibes. And maybe a little friendly arguing.</p>
          </section>
        )}

        {screen === 'game' && currentQuestion && (
          <section className="play-view animate-in" onTouchStart={(e) => { touchStart.current = e.touches[0].clientX }} onTouchEnd={handleTouchEnd}>
            <div className="game-topline">
              <button className="back-button" onClick={() => setScreen('home')} aria-label="Back to home">←</button>
              <div className="round-label">THE LOVE QUIZ <span>·</span> ROUND {idx + 1} OF {rounds.length}</div>
              <div className="score-pill">♡ {score}</div>
            </div>
            <div className="progress-track" aria-label={`Question ${idx + 1} of ${rounds.length}`}><div className="progress-fill" style={{ width: `${((idx + 1) / rounds.length) * 100}%` }} /></div>
            <div className="question-heading"><span className="question-kicker">LET'S FIND OUT</span><h1>{currentQuestion.q}</h1><p>Pick what feels right. No peeking! 👀</p></div>

            <div className="player-panels">
              {['p1', 'p2'].map((player, playerIndex) => (
                <section className={`player-panel ${picks[player] !== null ? 'player-done' : ''}`} key={player}>
                  <div className="player-panel-heading"><div className={`avatar avatar-${playerIndex + 1}`}>{(names[player].trim()[0] || (playerIndex === 0 ? '1' : '2')).toUpperCase()}</div><div><span className="player-label">PLAYER {playerIndex + 1}</span><h2>{names[player].trim()}</h2></div><span className="player-status">{picks[player] !== null ? '✓' : '•'}</span></div>
                  <div className="answer-list">
                    {currentQuestion.options.map((option, optionIndex) => {
                      const chosen = picks[player] === optionIndex
                      const matched = revealed && chosen && isMatch
                      const missed = revealed && chosen && !isMatch
                      return <button key={option} className={`answer-option ${chosen ? 'chosen' : ''} ${matched ? 'matched' : ''} ${missed ? 'missed' : ''}`} disabled={picks[player] !== null} onClick={() => pick(player, optionIndex)}><span className="option-letter">{String.fromCharCode(65 + optionIndex)}</span><span className="option-copy">{option}</span><span className="option-check">{chosen ? '✓' : '＋'}</span></button>
                    })}
                  </div>
                </section>
              ))}
            </div>

            {revealed ? (
              <div className={`reveal-panel animate-in ${isMatch ? 'reveal-match' : 'reveal-miss'}`} role="status">
                <div className="reveal-emoji">{isMatch ? '🥹' : '🤭'}</div><div className="reveal-copy"><strong>{isMatch ? 'Same brain, same heart!' : 'Plot twist!'}</strong><span>{isMatch ? 'You two are so in sync. +100 points' : 'Opposites keep it interesting. +20 points'}</span></div>
                <button className="next-button" onClick={nextRound}>{idx + 1 === rounds.length ? 'See our result' : 'Next question'} <span>→</span></button>
              </div>
            ) : <div className="waiting-note"><span className="waiting-dot" /> {picks.p1 !== null || picks.p2 !== null ? 'Waiting for your person to answer…' : 'Both answer to reveal your match'} </div>}
            {revealed && <p className="swipe-hint">Psst… swipe left to continue <span>←</span></p>}
          </section>
        )}

        {screen === 'result' && (
          <section className="result-view animate-in">
            <div className="result-confetti" aria-hidden="true">✦　♡　✧　♥　✦</div>
            <div className="result-stamp">{matches >= 4 ? 'SOULMATES?' : matches >= 2 ? 'CUTE DUO' : 'UNPREDICTABLE'}</div>
            <div className="result-heart" aria-hidden="true">{matches >= 4 ? '💘' : matches >= 2 ? '💕' : '💞'}</div>
            <p className="question-kicker">THE RESULTS ARE IN</p>
            <h1>{matches >= 4 ? 'Okay, you REALLY get each other.' : matches >= 2 ? 'You’ve got your own kind of magic.' : 'The plot twists are part of the love story.'}</h1>
            <p className="result-couple">{coupleName}</p>
            <div className="result-score-card"><span>YOUR LOVE SCORE</span><strong>{score}<small> pts</small></strong><div className="result-score-bottom"><span>♡ {matches} of {rounds.length} matches</span><span>{Math.round((matches / rounds.length) * 100)}% in sync</span></div><div className="result-meter"><span style={{ width: `${(matches / rounds.length) * 100}%` }} /></div></div>
            <div className="result-actions"><button className="primary-button" onClick={startGame}><span>Play again together</span><span className="button-arrow">↻</span></button><button className="secondary-button" onClick={() => setScreen('leaderboard')}>See the leaderboard ↗</button></div>
            <p className="tiny-note">The best score is the time you spend together. ♡</p>
          </section>
        )}

        {screen === 'leaderboard' && (
          <section className="leaderboard-view animate-in">
            <div className="leaderboard-hero"><span className="question-kicker">A LITTLE FRIENDLY COMPETITION</span><div className="leaderboard-cup">♛</div><h1>Couples <span>in sync.</span></h1><p>Our little hall of love and legendary guesses.</p></div>
            <div className="leaderboard-card"><div className="leaderboard-card-head"><div><span className="step-label">THE TOP 10</span><h2>Love league</h2></div><span className="leaderboard-heart">♡</span></div>
              {board.length === 0 ? <div className="empty-board"><span>♡</span><h3>Your names belong here.</h3><p>Play your first round and make it onto the board.</p><button className="primary-button" onClick={() => setScreen('home')}><span>Play the quiz</span><span className="button-arrow">↗</span></button></div> : <ol className="leaderboard-list">{board.map((row, i) => <li key={`${row.couple}-${row.date}-${i}`} className={i < 3 ? 'top-rank' : ''}><span className="rank-number">{String(i + 1).padStart(2, '0')}</span><span className="rank-heart">{i === 0 ? '♥' : i === 1 ? '♡' : '·'}</span><span className="rank-couple"><strong>{row.couple}</strong><small>{row.date || 'Love always'}</small></span><span className="rank-score">{row.score}<small>PTS</small></span></li>)}</ol>}
              <div className="leaderboard-footnote">Scores are saved on this device only.</div>
              {board.length > 0 && <button className="clear-board" onClick={clearBoard}>Reset local leaderboard</button>}
            </div>
            <button className="secondary-button return-button" onClick={() => setScreen('home')}>← Back to the good stuff</button>
          </section>
        )}
      </main>

      <footer className="site-footer"><span>made with <span className="footer-heart">♥</span> for two</span><span>HEYCUTU © {new Date().getFullYear()}</span></footer>
    </div>
  )
}
