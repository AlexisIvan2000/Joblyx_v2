import { Component } from 'react';

export class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error, info) {
    // Trace en console pour le diagnostic (le backend logue déjà ses propres erreurs)
    console.error('Panel admin render error:', error, info);
  }

  handleReload = () => {
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '16px',
            height: '100vh',
            padding: '24px',
            textAlign: 'center',
            color: 'var(--color-text)',
          }}
        >
          <h1 style={{ fontSize: '20px', margin: 0 }}>Une erreur est survenue</h1>
          <p style={{ color: 'var(--color-text-muted)', margin: 0 }}>
            Le panel a rencontré un problème inattendu.
          </p>
          <button className="btn btn-primary" onClick={this.handleReload}>
            Recharger la page
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
