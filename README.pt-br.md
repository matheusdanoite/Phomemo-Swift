# Phomemo T02 Swift

[English](README.md)

Um aplicativo iOS construído com SwiftUI e CoreBluetooth para imprimir imagens na impressora térmica Phomemo T02. Este projeto demonstra técnicas avançadas de processamento de imagem e comunicação Bluetooth Low Energy (BLE) para entregar impressões de 1-bit de alta qualidade. Ele também apresenta um sistema experimental de compartilhamento de impressora via Bluetooth.

## Funcionalidades
- **Impressão Direta via Bluetooth**: Conecte-se e imprima facilmente em dispositivos Phomemo T02.
- **Dithering de Imagem Avançado**: Escolha entre múltiplos algoritmos para converter imagens em escala de cinza para bitmaps de 1-bit:
  - **Floyd-Steinberg**: Fornece difusão de erro de alta qualidade para fotos detalhadas.
  - **Halftone**: Simula impressão tradicional de jornal com padrões de pontos.
  - **Threshold**: Binarização simples de alto contraste para texto e arte linear.
- **Suporte a Câmera e Galeria**: Capture novas fotos ou selecione existentes da sua biblioteca.
- **Preparação Inteligente de Imagem**: Lida automaticamente com rotação, redimensionamento e ajustes de contraste para o papel térmico de 58mm.
- **Temas Personalizados**: Alterne entre temas padrão e "Modo Rosa".
- **Compartilhamento de Impressora (Experimental)**: Compartilhe uma impressora conectada com outro dispositivo via Bluetooth.

## Compartilhamento de Impressora
Ao conectar seu dispositivo a uma impressora Phomemo T02, você pode compartilhar a impressora com outro dispositivo via Bluetooth. Isso permite imprimir de múltiplos dispositivos sem precisar conectar cada um individualmente à impressora. O dispositivo hospedeiro exibirá um selo "Host" no menu de Settings e quantos Clients estão conectados; os clients exibirão um selo "Client" no menu de Settings.

## Instalação
1. Clone o repositório.
2. Abra `Phomemo T02 Swift.xcodeproj` no Xcode 13 ou superior.
3. Certifique-se de que seu dispositivo alvo esteja rodando iOS 15.6+.
4. Copile e execute em um dispositivo físico (recursos de Bluetooth são necessários e não funcionam no Simulador).

## Uso
1. **Conectar**: Inicie o aplicativo e ele se conectará automaticamente à impressora.
2. **Capturar/Selecionar**: Use a visualização da câmera para tirar uma foto ou toque no ícone da galeria para escolher uma imagem.
3. **Editar**: O aplicativo processa a imagem automaticamente. Você pode ajustar o algoritmo de dithering deslizando da esquerda para a direita na pré-visualização, e definir a intensidade deslizando para cima e para baixo.
4. **Imprimir**: Toque no botão de imprimir para enviar os dados para a impressora.
5. **Configurações**: Deslize para cima a partir do botão de captura ou do botão da impressora para acessar o meu Settings.

## Arquitetura
- **PhomemoDriver**: Gerencia interações CoreBluetooth, escaneamento, conexão e envio de comandos de bytes brutos para a impressora.
- **PhomemoImageProcessor**: Usa o framework `Accelerate` da Apple (vImage) e `CoreImage` para manipulação de imagem e dithering de alta performance.
- **SwiftUI**: Fornece uma interface de usuário moderna e reativa com padrão MVVM (`ContentViewModel`).

## Requisitos
- iOS 15.6+
- Xcode 13.0+
- Impressora Phomemo T02

## Licença
Este projeto está licenciado sob a Licença MIT.

*matheusdanoite - do meu pc para a sua casa*
