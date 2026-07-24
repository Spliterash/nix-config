{ ... }: {
  services.ollama = {
    enable = true;
    acceleration = "rocm";
    environmentVariables = {
      OLLAMA_MODELS = "/mnt/data/Software/Ollama/";
      OLLAMA_CONTEXT_LENGTH = "200000";
      OLLAMA_GPU_OVERHEAD = toString (512 * 1024 * 1024); # ≈ 0.6 ГБ
    };
  };
}
