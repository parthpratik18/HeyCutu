import { useState } from 'react'

const BOARD_KEY = 'heycutu-leaderboard'

const QUESTIONS = [
  { q: 'Mera favourite food?', options: ['Pizza', 'Biryani', 'Pasta', 'Dosa'] },
  { q: 'Mera dream travel destination?', options: ['Japan', 'Paris', 'Goa', 'Maldives'] },
  { q: 'Mera favourite movie genre?', options: ['Romance', 'Comedy', 'Thriller', 'Action'] },
  { q: 'Mujhe sabse zyada kya pasand hai?', options: ['Coffee', 'Chai', 'Juice', 'Soda'] },
  { q: 'Meri love language?', options: ['Words', 'Touch', 'Time', 'Gifts'] },
  { q: 'Mera perfect weekend?', options: ['Ghar par aaram', 'Road trip', 'Party', 'Shopping'] },
  { q: 'Mera favourite season?', options: ['Monsoon', 'Winter', 'Summer', 'Spring'] },
]

function shuffle(arr) {
  const copy = [...arr]
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}

function loadBoard() {
  try {
    return JSON.parse(localStorage.getItem(BOARD_KEY)) || []
  } catch {
    return []
  }
}

function saveBoard(board) {
  try {
    localStorage.setItem(BOARD_KEY, JSON.stringify(board))
  } catch {
    // localStorage band ho to chup rahein
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

  const coupleName = `${names.p1.trim()} & ${names.p2.trim()}`
  const revealed = picks.p1 !== null && picks.p2 !== null

  function startGame() {
    if (!names.p1.trim() || !names.p2.trim()) {
      setError('Dono partners ke naam likhein')
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
    setPicks({ ...picks, [player]: optionIndex })
  }

  function nextRound() {
    const isMatch = picks.p1 === picks.p2
    const newScore = score + (isMatch ? 100 : 20)
    const newMatches = matches + (isMatch ? 1 : 0)

    if (idx + 1 >= rounds.length) {
      const entry = {
        couple: coupleName,
        score: newScore,
        matches: newMatches,
        date: new Date().toLocaleDateString('en-IN'),
      }
      const updated = [...board, entry].sort((a, b) => b.score - a.score).slice(0, 10)
      setBoard(updated)
      saveBoard(updated)
      setScore(newScore)
      setMatches(newMatches)
      setScreen('result')
    } else {
      setScore(newScore)
      setMatches(newMatches)
      setIdx(idx + 1)
      setPicks({ p1: null, p2: null })
    }
  }

  function resetBoard() {
    if (confirm('Kya aap sara leaderboard saaf karna chahte hain?')) {
      setBoard([])
      saveBoard([])
    }
  }

  return (
    <div className="app">
      <header className="header">
        <div className="logo">💬❤️</div>
        <h1 className="brand">HeyCutu</h1>
        <p className="tagline">The Fun Side of Love</p>
        <nav className="nav">
          <button onClick={() => setScreen('home')}>Home</button>
          <button onClick={() => setScreen('leaderboard')}>Leaderboard</button>
        </nav>
      </header>

      {screen === 'home' && (
        <main className="card">
          <h2>Love Question Battle 💘</h2>
          <p>
            Dono partners alag-alag answer dein. Jitne zyada answers match honge,
            utne zyada points milenge!
          </p>
          <div className="field">
            <label>Partner 1 ka naam</label>
            <input
              value={names.p1}
              maxLength={20}
              onChange={(e) => setNames({ ...names, p1: e.target.value })}
              placeholder="Jaise: Rohan"
            />
          </div>
          <div className="field">
            <label>Partner 2 ka naam</label>
            <input
              value={names.p2}
              maxLength={20}
              onChange={(e) => setNames({ ...names, p2: e.target.value })}
              placeholder="Jaise: Priya"
            />
          </div>
          {error && <p className="error">{error}</p>}
          <button className="btn primary" onClick={startGame}>
            Game Shuru Karein 🎮
          </button>
          <p className="hint">Scoring: match = 100 points, no match = 20 points</p>
        </main>
      )}

      {screen === 'game' && rounds.length > 0 && (
        <main className="card">
          <div className="progress">
            Question {idx + 1} / {rounds.length} • Score: {score}
          </div>
          <h2 className="question">{rounds[idx].q}</h2>

          <div className="players">
            {['p1', 'p2'].map((player) => (
              <div className="player" key={player}>
                <div className="player-name">{player === 'p1' ? names.p1 : names.p2}</div>
                {rounds[idx].options.map((opt, i) => {
                  const chosen = picks[player] === i
                  const cls = [
                    'option',
                    chosen ? 'chosen' : '',
                    revealed && chosen && picks.p1 === picks.p2 ? 'match' : '',
                  ].join(' ')
                  return (
                    <button
                      key={opt}
                      className={cls}
                      disabled={picks[player] !== null}
                      onClick={() => pick(player, i)}
                    >
                      {opt}
                    </button>
                  )
                })}
              </div>
            ))}
          </div>

          {revealed && (
            <div className="reveal">
              {picks.p1 === picks.p2 ? (
                <p className="match-text">🎉 Match! +100 points</p>
              ) : (
                <p className="miss-text">Alag answers, +20 points</p>
              )}
              <button className="btn primary" onClick={nextRound}>
                {idx + 1 >= rounds.length ? 'Result Dekhein' : 'Agla Sawal'}
              </button>
            </div>
          )}
        </main>
      )}

      {screen === 'result' && (
        <main className="card center">
          <div className="big-emoji">{matches >= 4 ? '🎉' : matches >= 2 ? '💕' : '💑'}</div>
          <h2>{coupleName}</h2>
          <p className="big-score">{score} points</p>
          <p>
            {matches} / {rounds.length} answers match hue
          </p>
          <div className="btn-row">
            <button className="btn" onClick={startGame}>Phir Khelein</button>
            <button className="btn primary" onClick={() => setScreen('leaderboard')}>
              Leaderboard Dekhein
            </button>
          </div>
        </main>
      )}

      {screen === 'leaderboard' && (
        <main className="card">
          <h2>🏆 Top Couples</h2>
          {board.length === 0 ? (
            <p className="hint">Abhi koi score nahi hai. Pehle game khelein!</p>
          ) : (
            <ol className="board">
              {board.map((row, i) => (
                <li key={i}>
                  <span className="rank">#{i + 1}</span>
                  <span className="couple">{row.couple}</span>
                  <span className="pts">{row.score} pts</span>
                </li>
              ))}
            </ol>
          )}
          <p className="hint">
            Ye leaderboard is device/browser par save hota hai. Sabke liye shared leaderboard ke liye
            README mein "Next step" dekhein.
          </p>
          {board.length > 0 && (
            <button className="btn" onClick={resetBoard}>Season Reset Karein</button>
          )}
        </main>
      )}

      <footer className="footer">© {new Date().getFullYear()} HeyCutu</footer>
    </div>
  )
}
