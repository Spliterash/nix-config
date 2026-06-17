{ ... }: {
  services.ollama = {
    enable = true;
    acceleration = "rocm";
    environmentVariables = {
      OLLAMA_MODELS = "/mnt/data/Software/Ollama/";
    };
  };
}
