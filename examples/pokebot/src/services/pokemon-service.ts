export interface PokemonSummary {
  id: number;
  name: string;
  types: string[];
  height: number;
  weight: number;
  image: string;
}

interface PokeApiResponse {
  id: number;
  name: string;
  types: Array<{ type: { name: string } }>;
  height: number;
  weight: number;
  sprites: {
    other?: {
      "official-artwork"?: {
        front_default?: string | null;
      };
    };
    front_default?: string | null;
  };
}

@service
export class PokemonService {
  private cache = new Map<string, PokemonSummary>();

  async getPokemon(nameOrId: string | number): Promise<PokemonSummary | null> {
    const key = String(nameOrId).trim().toLowerCase();
    if (!key) return null;

    if (this.cache.has(key)) {
      return this.cache.get(key)!;
    }

    const response = await fetch(`https://pokeapi.co/api/v2/pokemon/${encodeURIComponent(key)}`);
    if (!response.ok) {
      return null;
    }

    const data = (await response.json()) as PokeApiResponse;
    const summary = this.toSummary(data);

    this.cache.set(key, summary);
    this.cache.set(String(summary.id), summary);
    this.cache.set(summary.name, summary);

    return summary;
  }

  async getRandomPokemon(): Promise<PokemonSummary | null> {
    const id = Math.floor(Math.random() * 1025) + 1;
    return this.getPokemon(id);
  }

  private toSummary(data: PokeApiResponse): PokemonSummary {
    const image =
      data.sprites.other?.["official-artwork"]?.front_default ??
      data.sprites.front_default ??
      "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/0.png";

    return {
      id: data.id,
      name: data.name,
      types: data.types.map((entry) => entry.type.name),
      height: data.height,
      weight: data.weight,
      image
    };
  }
}
