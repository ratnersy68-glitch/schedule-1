import { useCallback, useRef, useState, type CSSProperties, type PointerEvent, type ReactNode } from 'react';

export interface DragHandleProps {
  onPointerDown: (e: PointerEvent<HTMLElement>) => void;
  style: CSSProperties;
}

interface Props<T> {
  items: T[];
  keyOf: (item: T) => string;
  onReorder: (from: number, to: number) => void;
  renderItem: (item: T, index: number, handle: DragHandleProps, dragging: boolean) => ReactNode;
  className?: string;
}

/**
 * Pointer-based reordering that works with touch as well as a mouse.
 * The dragged row follows the finger; the rows it passes slide out of the way.
 */
export default function DragList<T>({ items, keyOf, onReorder, renderItem, className = '' }: Props<T>) {
  const rowsRef = useRef<(HTMLLIElement | null)[]>([]);
  const geometry = useRef<{ centers: number[]; shift: number } | null>(null);
  const startY = useRef(0);
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [targetIndex, setTargetIndex] = useState<number | null>(null);
  const [offset, setOffset] = useState(0);

  const end = useCallback(() => {
    setDragIndex((from) => {
      setTargetIndex((to) => {
        if (from !== null && to !== null && from !== to) onReorder(from, to);
        return null;
      });
      return null;
    });
    setOffset(0);
    geometry.current = null;
  }, [onReorder]);

  const onPointerDown = (index: number) => (e: PointerEvent<HTMLElement>) => {
    if (items.length < 2) return;
    e.preventDefault();
    const rects = rowsRef.current.map((el) => el?.getBoundingClientRect() ?? null);
    if (rects.some((r) => r === null)) return;
    const valid = rects as DOMRect[];
    const gap = valid.length > 1 ? Math.max(0, valid[1].top - valid[0].bottom) : 0;
    geometry.current = {
      centers: valid.map((r) => r.top + r.height / 2),
      shift: valid[index].height + gap,
    };
    startY.current = e.clientY;
    setDragIndex(index);
    setTargetIndex(index);
    setOffset(0);
    (e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
    if ('vibrate' in navigator) navigator.vibrate?.(10);
  };

  const onPointerMove = (e: PointerEvent<HTMLElement>) => {
    if (dragIndex === null || !geometry.current) return;
    e.preventDefault();
    const delta = e.clientY - startY.current;
    setOffset(delta);
    const { centers } = geometry.current;
    const center = centers[dragIndex] + delta;
    let next = dragIndex;
    if (delta > 0) {
      for (let i = dragIndex + 1; i < centers.length; i++) if (center > centers[i]) next = i;
    } else {
      for (let i = dragIndex - 1; i >= 0; i--) if (center < centers[i]) next = i;
    }
    setTargetIndex(next);
  };

  const transformFor = (index: number): CSSProperties => {
    if (dragIndex === null || targetIndex === null || !geometry.current) return {};
    if (index === dragIndex) {
      return {
        transform: `translateY(${offset}px) scale(1.02)`,
        zIndex: 30,
        position: 'relative',
        boxShadow: '0 12px 30px rgba(0,0,0,0.55)',
        transition: 'none',
      };
    }
    const { shift } = geometry.current;
    if (dragIndex < index && index <= targetIndex) {
      return { transform: `translateY(${-shift}px)`, transition: 'transform 0.14s ease' };
    }
    if (targetIndex <= index && index < dragIndex) {
      return { transform: `translateY(${shift}px)`, transition: 'transform 0.14s ease' };
    }
    return { transform: 'translateY(0px)', transition: 'transform 0.14s ease' };
  };

  return (
    <ul className={`flex flex-col gap-2 ${className}`}>
      {items.map((item, index) => (
        <li
          key={keyOf(item)}
          ref={(el) => {
            rowsRef.current[index] = el;
          }}
          style={transformFor(index)}
          onPointerMove={onPointerMove}
          onPointerUp={end}
          onPointerCancel={end}
        >
          {renderItem(
            item,
            index,
            {
              onPointerDown: onPointerDown(index),
              style: { touchAction: 'none', cursor: 'grab' },
            },
            dragIndex === index
          )}
        </li>
      ))}
    </ul>
  );
}
