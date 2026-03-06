import { useService } from "wum.js/hooks";
import { PokemonService } from "../services/pokemon-service";

interface PokemonView {
  id: number;
  name: string;
  types: string[];
  height: number;
  weight: number;
  image: string;
}

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function PokemonCard({ pokemon }: { pokemon: PokemonView }) {
  const typeList = pokemon.types.map(titleCase).join(", ");
  const description = `Type: ${typeList}\nHeight: ${pokemon.height}\nWeight: ${pokemon.weight}`;

  return (
    <interaction>
      <embed color={0xef5350}>
        <title>#{pokemon.id} {titleCase(pokemon.name)}</title>
        <description>{description}</description>
        <thumbnail>{pokemon.image}</thumbnail>
      </embed>
    </interaction>
  );
}

export default (
  <command name="pokemon" description="Pokemon lookup commands">
    <subcommand name="info" description="Show details about a Pokemon">
      <string name="name" description="Pokemon name or id" />
      {async (interaction) => {
        const pokemonService = useService(PokemonService);
        const name = interaction.options.getString("name", true);
        const pokemon = await pokemonService.getPokemon(name);

        if (!pokemon) {
          return <interaction ephemeral>Pokemon not found: {name}</interaction>;
        }

        return <PokemonCard pokemon={pokemon} />;
      }}
    </subcommand>

    <subcommand name="random" description="Get a random Pokemon">
      {async () => {
        const pokemonService = useService(PokemonService);
        const pokemon = await pokemonService.getRandomPokemon();

        if (!pokemon) {
          return <interaction ephemeral>Failed to fetch a random Pokemon.</interaction>;
        }

        return <PokemonCard pokemon={pokemon} />;
      }}
    </subcommand>
  </command>
);
