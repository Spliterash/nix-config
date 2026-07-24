{ ... }:
{
  # Мышь конкретно на этом ПК (COMPANY USB Device) — hardware-специфично, не в common plasma.
  programs.plasma.input.mice = [
    {
      name = "COMPANY  USB Device ";
      vendorId = "09DA";
      productId = "50CA";
      acceleration = 0.2; # PointerAcceleration=0.200
      accelerationProfile = "none"; # PointerAccelerationProfile=1
    }
  ];
}
