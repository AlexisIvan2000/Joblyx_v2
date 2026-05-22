import { Search } from 'lucide-react';
import '../styles/components/form.css';

export default function SearchInput({ value, onChange, placeholder = 'Rechercher…' }) {
  return (
    <div className="search-input-wrapper">
      <Search className="search-icon" size={16} strokeWidth={2.25} />
      <input
        type="search"
        className="search-input"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
      />
    </div>
  );
}
